# Secrets Management

> Gestion securisee des secrets, credentials et cles de chiffrement.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                    Secrets Lifecycle                             │
│                                                                  │
│   Generate ──► Store ──► Distribute ──► Use ──► Rotate ──► Revoke│
│      │          │           │           │         │          │  │
│      ▼          ▼           ▼           ▼         ▼          ▼  │
│   Strong     Encrypted   Secure      In-memory  Automated   Audit│
│   entropy    at rest     transport   only       schedule     log │
└─────────────────────────────────────────────────────────────────┘
```

## Environment Variables (Basic)

```typescript
// config.ts - Type-safe environment loading
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  API_KEY: z.string().min(16),
  AWS_ACCESS_KEY_ID: z.string().optional(),
  AWS_SECRET_ACCESS_KEY: z.string().optional(),
});

function loadConfig() {
  const result = envSchema.safeParse(process.env);

  if (!result.success) {
    console.error('Invalid environment variables:');
    console.error(result.error.format());
    process.exit(1);
  }

  return result.data;
}

export const config = loadConfig();

// Usage
import { config } from './config';
const secret = config.JWT_SECRET; // Type-safe
```

## HashiCorp Vault Integration

```typescript
import Vault from 'node-vault';

interface VaultConfig {
  endpoint: string;
  token?: string;
  roleId?: string;
  secretId?: string;
}

class VaultClient {
  private client: Vault.client;
  private cache = new Map<string, { value: any; expiresAt: number }>();
  private cacheTTL = 5 * 60 * 1000; // 5 minutes

  constructor(config: VaultConfig) {
    this.client = Vault({
      apiVersion: 'v1',
      endpoint: config.endpoint,
      token: config.token,
    });
  }

  async authenticate(roleId: string, secretId: string): Promise<void> {
    const result = await this.client.approleLogin({
      role_id: roleId,
      secret_id: secretId,
    });
    this.client.token = result.auth.client_token;
  }

  async getSecret(path: string): Promise<Record<string, string>> {
    // Check cache
    const cached = this.cache.get(path);
    if (cached && Date.now() < cached.expiresAt) {
      return cached.value;
    }

    // Fetch from Vault
    const result = await this.client.read(`secret/data/${path}`);
    const secrets = result.data.data;

    // Cache result
    this.cache.set(path, {
      value: secrets,
      expiresAt: Date.now() + this.cacheTTL,
    });

    return secrets;
  }

  async setSecret(path: string, data: Record<string, string>): Promise<void> {
    await this.client.write(`secret/data/${path}`, { data });
    this.cache.delete(path);
  }

  async deleteSecret(path: string): Promise<void> {
    await this.client.delete(`secret/metadata/${path}`);
    this.cache.delete(path);
  }
}

// Usage
const vault = new VaultClient({
  endpoint: 'https://vault.example.com',
});
await vault.authenticate(process.env.VAULT_ROLE_ID!, process.env.VAULT_SECRET_ID!);

const dbSecrets = await vault.getSecret('database/credentials');
const dbUrl = `postgres://${dbSecrets.username}:${dbSecrets.password}@db.example.com/app`;
```

## AWS Secrets Manager

```typescript
import {
  SecretsManagerClient,
  GetSecretValueCommand,
  CreateSecretCommand,
  UpdateSecretCommand,
  RotateSecretCommand,
} from '@aws-sdk/client-secrets-manager';

class AWSSecretsManager {
  private client: SecretsManagerClient;
  private cache = new Map<string, { value: any; expiresAt: number }>();

  constructor(region: string = 'us-east-1') {
    this.client = new SecretsManagerClient({ region });
  }

  async getSecret(secretName: string): Promise<Record<string, any>> {
    // Check cache
    const cached = this.cache.get(secretName);
    if (cached && Date.now() < cached.expiresAt) {
      return cached.value;
    }

    const command = new GetSecretValueCommand({ SecretId: secretName });
    const response = await this.client.send(command);

    let secret: Record<string, any>;
    if (response.SecretString) {
      secret = JSON.parse(response.SecretString);
    } else if (response.SecretBinary) {
      secret = JSON.parse(Buffer.from(response.SecretBinary).toString());
    } else {
      throw new Error('No secret value found');
    }

    // Cache for 5 minutes
    this.cache.set(secretName, {
      value: secret,
      expiresAt: Date.now() + 5 * 60 * 1000,
    });

    return secret;
  }

  async createSecret(name: string, value: Record<string, any>): Promise<void> {
    const command = new CreateSecretCommand({
      Name: name,
      SecretString: JSON.stringify(value),
    });
    await this.client.send(command);
  }

  async rotateSecret(name: string): Promise<void> {
    const command = new RotateSecretCommand({
      SecretId: name,
      RotateImmediately: true,
    });
    await this.client.send(command);
    this.cache.delete(name);
  }
}
```

## Secret Rotation

```typescript
interface RotatableSecret {
  name: string;
  currentVersion: string;
  rotationSchedule: string; // cron expression
  rotate(): Promise<void>;
}

class DatabaseCredentialRotation implements RotatableSecret {
  name = 'database-credentials';
  currentVersion = '';
  rotationSchedule = '0 0 * * 0'; // Weekly

  constructor(
    private vault: VaultClient,
    private db: DatabaseAdmin,
  ) {}

  async rotate(): Promise<void> {
    // 1. Generate new password
    const newPassword = this.generateSecurePassword();

    // 2. Update database user password
    await this.db.updateUserPassword('app_user', newPassword);

    // 3. Update in Vault
    await this.vault.setSecret('database/credentials', {
      username: 'app_user',
      password: newPassword,
      rotatedAt: new Date().toISOString(),
    });

    // 4. Notify applications to reload
    await this.notifyApplications();

    console.log(`Rotated ${this.name} successfully`);
  }

  private generateSecurePassword(): string {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return Array.from(array, (byte) => chars[byte % chars.length]).join('');
  }

  private async notifyApplications(): Promise<void> {
    // Send signal to reload config
    // Could be: Redis pub/sub, webhook, Kubernetes rolling restart
  }
}

class SecretRotationScheduler {
  private jobs: Map<string, NodeJS.Timeout> = new Map();

  schedule(secret: RotatableSecret): void {
    const interval = this.cronToMs(secret.rotationSchedule);

    const job = setInterval(async () => {
      try {
        await secret.rotate();
      } catch (error) {
        console.error(`Failed to rotate ${secret.name}:`, error);
        // Alert ops team
      }
    }, interval);

    this.jobs.set(secret.name, job);
  }

  private cronToMs(cron: string): number {
    // Simplified - use a real cron parser
    return 7 * 24 * 60 * 60 * 1000; // 1 week
  }
}
```

## Encryption at Rest

```typescript
import crypto from 'crypto';

class SecretEncryption {
  private algorithm = 'aes-256-gcm';
  private keyLength = 32;
  private ivLength = 16;
  private tagLength = 16;

  constructor(private masterKey: Buffer) {
    if (masterKey.length !== this.keyLength) {
      throw new Error('Master key must be 32 bytes');
    }
  }

  encrypt(plaintext: string): string {
    const iv = crypto.randomBytes(this.ivLength);
    const cipher = crypto.createCipheriv(this.algorithm, this.masterKey, iv);

    let encrypted = cipher.update(plaintext, 'utf8', 'base64');
    encrypted += cipher.final('base64');

    const tag = cipher.getAuthTag();

    // Combine: iv + tag + ciphertext
    return Buffer.concat([iv, tag, Buffer.from(encrypted, 'base64')]).toString('base64');
  }

  decrypt(ciphertext: string): string {
    const buffer = Buffer.from(ciphertext, 'base64');

    const iv = buffer.subarray(0, this.ivLength);
    const tag = buffer.subarray(this.ivLength, this.ivLength + this.tagLength);
    const encrypted = buffer.subarray(this.ivLength + this.tagLength);

    const decipher = crypto.createDecipheriv(this.algorithm, this.masterKey, iv);
    decipher.setAuthTag(tag);

    let decrypted = decipher.update(encrypted);
    decrypted = Buffer.concat([decrypted, decipher.final()]);

    return decrypted.toString('utf8');
  }
}
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `node-vault` | HashiCorp Vault client |
| `@aws-sdk/client-secrets-manager` | AWS Secrets Manager |
| `@google-cloud/secret-manager` | GCP Secret Manager |
| `@azure/keyvault-secrets` | Azure Key Vault |
| `dotenv` | Local .env loading |
| `dotenv-vault` | Encrypted .env sync |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Secrets dans git | Exposition publique | .gitignore, git-secrets |
| Secrets en logs | Leakage | Masquer dans logs |
| Pas de rotation | Breach persistante | Rotation automatique |
| Hardcoded secrets | Difficile a changer | Toujours externaliser |
| Secrets partages | Blast radius large | Secrets par service |
| Pas de chiffrement au repos | Breach si acces storage | Toujours chiffrer |

## Best practices

```yaml
# Checklist secrets management
checklist:
  storage:
    - [ ] Jamais en clair dans le code
    - [ ] Jamais dans git (meme prive)
    - [ ] Chiffre au repos
    - [ ] Access control strict

  transport:
    - [ ] TLS obligatoire
    - [ ] Pas dans URLs
    - [ ] Pas dans logs

  lifecycle:
    - [ ] Rotation automatique
    - [ ] Revocation possible
    - [ ] Audit trail complet

  access:
    - [ ] Least privilege
    - [ ] Un secret par usage
    - [ ] Expiration si possible
```

## Patterns lies

- **OAuth 2.0** : Tokens plutot que credentials
- **JWT** : Signing keys a proteger
- **Encryption** : Master key management

## Sources

- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [HashiCorp Vault](https://developer.hashicorp.com/vault/docs)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)

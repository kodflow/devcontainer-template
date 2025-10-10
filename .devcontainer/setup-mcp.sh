#!/bin/bash
set -e

VAULT_ID="ypahjj334ixtiyjkytu5hij2im"
MCP_TPL="/workspace/.devcontainer/mcp.json.tpl"
MCP_OUTPUT="/home/vscode/.devcontainer/mcp.json"

echo "🔐 Récupération des secrets depuis 1Password..."

# Vérifier que op est installé
if ! command -v op &> /dev/null; then
    echo "❌ 1Password CLI n'est pas installé"
    exit 1
fi

# Récupérer les tokens depuis 1Password
echo "  → Récupération du token Codacy..."
CODACY_TOKEN=$(op item get "mcp-codacy" --vault "$VAULT_ID" --fields credential --reveal 2>/dev/null || echo "")

echo "  → Récupération du token GitHub..."
GITHUB_TOKEN=$(op item get "mcp-github" --vault "$VAULT_ID" --fields credential --reveal 2>/dev/null || echo "")

# Vérifier que les tokens ont été récupérés
if [ -z "$CODACY_TOKEN" ]; then
    echo "⚠️  Token Codacy non trouvé dans 1Password"
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  Token GitHub non trouvé dans 1Password"
fi

# Générer le fichier mcp.json à partir du template
echo "📝 Génération du fichier mcp.json..."
mkdir -p "$(dirname "$MCP_OUTPUT")"
cat "$MCP_TPL" | \
    sed "s|{{ with secret \"secret/mcp/codacy\" }}{{ .Data.data.token }}{{ end }}|${CODACY_TOKEN}|g" | \
    sed "s|{{ with secret \"secret/mcp/github\" }}{{ .Data.data.token }}{{ end }}|${GITHUB_TOKEN}|g" \
    > "$MCP_OUTPUT"

echo "✅ Fichier mcp.json généré avec succès!"

# Configurer les paramètres Claude CLI
echo "⚙️  Configuration de Claude CLI..."
cat > /home/vscode/.claude/settings.json <<'EOF'
{
  "enableAllProjectMcpServers": true,
  "alwaysThinkingEnabled": true
}
EOF
echo "✅ Paramètres Claude CLI configurés!"

{
  "mcpServers": {
    "grepai": {
      "command": "/usr/local/bin/grepai",
      "args": ["mcp-serve"]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@0.x"],
      "env": {}
    },
    "codacy": {
      "command": "npx",
      "args": ["-y", "@codacy/codacy-mcp@0.x"],
      "env": {
        "CODACY_ACCOUNT_TOKEN": "{{CODACY_TOKEN}}"
      }
    },
    "github": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
        "ghcr.io/github/github-mcp-server"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "{{GITHUB_TOKEN}}"
      }
    },
    "playwright": {
      "command": "npx",
      "args": [
        "-y",
        "@playwright/mcp@0.x",
        "--headless",
        "--caps", "core,pdf,testing,tracing"
      ]
    },
    "gitlab": {
      "command": "npx",
      "args": ["-y", "@zereight/mcp-gitlab@1.x"],
      "env": {
        "GITLAB_PERSONAL_ACCESS_TOKEN": "{{GITLAB_TOKEN}}",
        "GITLAB_API_URL": "{{GITLAB_API_URL:-https://gitlab.com/api/v4}}"
      }
    }
  }
}

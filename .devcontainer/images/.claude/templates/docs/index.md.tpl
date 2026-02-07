<!-- /docs-generated: {"date":"{{TIMESTAMP}}","commit":"{{LAST_COMMIT_SHA}}","pages":{{TOTAL_PAGES}},"agents":{{N}}} -->

<div class="hero" markdown>

# {{PROJECT_NAME}}

**{{PROJECT_TAGLINE}}**

[How to use :material-arrow-right:](docs/){ .md-button .md-button--primary }

</div>

---

<!-- IF INTERNAL_PROJECT == true: simple feature table -->
<!-- USE THIS VARIANT for internal projects -->
<!--
## Features

| Feature | Description |
|---------|-------------|
| **{{FEATURE_NAME}}** | {{FEATURE_DESCRIPTION}} |
-->

<!-- IF INTERNAL_PROJECT == false: competitive comparison table -->
<!-- USE THIS VARIANT for external projects -->
<!--
## Feature Comparison

| Feature | {{PROJECT_NAME}} :star: | {{COMPETITOR_A}} | {{COMPETITOR_B}} | {{COMPETITOR_C}} |
|---------|:-:|:-:|:-:|:-:|
| **{{FEATURE_NAME}}** | :white_check_mark: | :warning: | :x: | :x: |
| **Price** | Free | $$$ | Free | $$ |
{{IF_PUBLIC_REPO}}| **Open Source** | :white_check_mark: | :x: | :white_check_mark: | :x: |{{/IF_PUBLIC_REPO}}

> :white_check_mark: Full support | :warning: Partial | :x: Not available
-->

## How it works

```mermaid
{{OVERVIEW_DIAGRAM}}
```

{{OVERVIEW_EXPLANATION}}

## Quick Start

{{QUICK_START_STEPS}}

---

*{{PROJECT_NAME}} · {{LICENSE}}{{IF_PUBLIC_REPO}} · [:material-github: GitHub]({{GIT_REMOTE_URL}}){{/IF_PUBLIC_REPO}}*

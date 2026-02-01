site_name: "{{PROJECT_NAME}} Documentation"
site_description: "Technical documentation for {{PROJECT_NAME}}"
site_url: ""
repo_url: "{{REPO_URL}}"
edit_uri: "edit/main/docs/"

docs_dir: docs
site_dir: site

theme:
  name: material
  palette:
    - scheme: default
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - scheme: slate
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.tabs
    - navigation.sections
    - navigation.expand
    - navigation.top
    - search.highlight
    - search.share
    - content.code.copy
    - content.tabs.link
  icon:
    repo: fontawesome/brands/github

plugins:
  - search
  - mermaid2

markdown_extensions:
  - pymdownx.highlight:
      anchor_linenums: true
      line_spans: __span
      pygments_lang_class: true
  - pymdownx.inlinehilite
  - pymdownx.snippets
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - pymdownx.tabbed:
      alternate_style: true
  - pymdownx.details
  - admonition
  - attr_list
  - md_in_html
  - tables
  - toc:
      permalink: true

nav:
  - Home: index.md
  - Architecture:
      - Overview: architecture/README.md
      - C4 Context: architecture/c4-context.md
      - C4 Container: architecture/c4-container.md
      - C4 Component: architecture/c4-component.md
  - ADR:
      - Overview: adr/README.md
  - API: api/README.md
  - Runbooks: runbooks/README.md
  - Guides: guides/README.md

extra:
  social:
    - icon: fontawesome/brands/github
      link: "{{REPO_URL}}"
  generator: false

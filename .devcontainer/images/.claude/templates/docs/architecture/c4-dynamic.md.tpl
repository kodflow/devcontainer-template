# Dynamic Diagrams (C4 Flows)

Key data flows and interaction sequences in **{{PROJECT_NAME}}**.

**Audience:** Developers, architects understanding system behavior.

<!-- GENERATION RULES:
  Condition: Generate one C4Dynamic per critical flow detected:
    - Primary user journey (most common use case)
    - Authentication flow (if auth exists)
    - Data processing pipeline (if applicable)

  Max 3 dynamic diagrams per page.
  If more flows exist, only document the most critical ones.
-->

<!-- FOR EACH critical flow: -->

## {{FLOW_NAME}}

{{FLOW_DESCRIPTION}}

```mermaid
C4Dynamic
    title {{FLOW_NAME}} — {{PROJECT_NAME}}

    {{C4_DYNAMIC_ELEMENTS}}

    {{C4_DYNAMIC_RELATIONSHIPS}}

    {{C4_DYNAMIC_STYLES}}
```

<!-- GENERATION RULES:
  Elements:
    - Reuse Container/Component elements from Level 2/3
    - Only include elements involved in THIS flow

  Relationships:
    - Rel(from, to, "N. Action description", "Protocol")
    - Number steps sequentially in the label: "1. Submit credentials"
    - Order of Rel() statements determines sequence (Mermaid ignores RelIndex)

  Styling:
    - UpdateRelStyle(from, to, $textColor="red") for error paths
    - UpdateRelStyle(from, to, $textColor="blue") for async operations

  Constraints:
    - Max 10 steps per flow diagram
    - If flow is longer, split into sub-flows
    - Always show error/failure path for critical flows
-->

### Flow Steps

| Step | From | To | Action | Protocol |
|:----:|------|-----|--------|----------|
<!-- FOR EACH step in the flow -->
<!-- | 1 | Client | API Gateway | POST /login | HTTPS/JSON | -->
<!-- | 2 | API Gateway | Auth Service | Validate credentials | gRPC | -->
<!-- | 3 | Auth Service | User DB | SELECT user | JDBC | -->
<!-- | 4 | Auth Service | API Gateway | Return JWT | gRPC | -->
<!-- | 5 | API Gateway | Client | 200 OK + token | HTTPS/JSON | -->

### Error Scenarios

| Step | Condition | Response | HTTP Code |
|:----:|-----------|----------|:---------:|
<!-- | 2 | Invalid credentials | 401 Unauthorized | 401 | -->
<!-- | 3 | DB unavailable | 503 Service Unavailable | 503 | -->

---

*[Back to Architecture Overview](README.md)*

# Principes de Conception

Principes fondamentaux et patterns de programmation défensive.

---

## Fichiers

| Fichier | Contenu | Patterns |
|---------|---------|----------|
| [SOLID.md](SOLID.md) | 5 principes OOP | SRP, OCP, LSP, ISP, DIP |
| [DRY.md](DRY.md) | Don't Repeat Yourself | Factorisation |
| [KISS.md](KISS.md) | Keep It Simple | Simplicité |
| [YAGNI.md](YAGNI.md) | You Ain't Gonna Need It | Éviter la sur-ingénierie |
| [GRASP.md](GRASP.md) | 9 patterns de responsabilité | Expert, Creator, Controller... |
| [defensive.md](defensive.md) | 11 patterns défensifs | Guard Clause, Assertions... |

---

## SOLID (5 principes)

| Principe | Description |
|----------|-------------|
| **S**ingle Responsibility | Une classe = une raison de changer |
| **O**pen/Closed | Ouvert à l'extension, fermé à la modification |
| **L**iskov Substitution | Sous-types substituables |
| **I**nterface Segregation | Interfaces spécifiques > génériques |
| **D**ependency Inversion | Dépendre des abstractions |

---

## GRASP (9 patterns)

| Pattern | Question | Réponse |
|---------|----------|---------|
| Information Expert | Qui fait X ? | Celui qui a les données |
| Creator | Qui crée X ? | Celui qui contient/utilise X |
| Controller | Qui reçoit les requêtes ? | Un coordinateur dédié |
| Low Coupling | Réduire dépendances ? | Interfaces, DI |
| High Cohesion | Garder le focus ? | Une responsabilité/classe |
| Polymorphism | Éviter switch sur type ? | Interfaces + implémentations |
| Pure Fabrication | Logique orpheline ? | Classe dédiée (Service, Repo) |
| Indirection | Découpler A de B ? | Ajouter intermédiaire |
| Protected Variations | Isoler changements ? | Interfaces stables |

---

## Defensive Programming (11 patterns)

| Pattern | Problème | Solution |
|---------|----------|----------|
| Guard Clause | Conditions imbriquées | Validation early return |
| Assertions | Invariants violés | Vérifier explicitement |
| Null Object | Null checks répétés | Objet neutre |
| Optional Chaining | Propriétés nullables | `?.` et `??` |
| Default Values | Valeurs manquantes | Defaults sûrs |
| Fail-Fast | Erreurs silencieuses | Échouer immédiatement |
| Input Validation | Données externes | Valider aux frontières |
| Type Guards | Types inconnus | Narrowing TypeScript |
| Immutability | Modifications accidentelles | Données immutables |
| Dependency Validation | Dépendances manquantes | Vérifier au démarrage |
| Design by Contract | Garanties formelles | Pré/post conditions |

---

## Tableau de décision rapide

| Problème | Principe/Pattern |
|----------|------------------|
| Classe fait trop de choses | SRP, High Cohesion |
| Code dupliqué | DRY |
| Code trop complexe | KISS |
| Feature "au cas où" | YAGNI |
| Variables nulles partout | Guard Clause, Null Object |
| Conditions imbriquées | Guard Clause |
| Couplage fort | Low Coupling, DIP |
| Switch sur types | Polymorphism |
| Où mettre la logique ? | Information Expert |
| Qui crée les objets ? | Creator |

---

## Hiérarchie d'application

```
1. SOLID (fondamentaux OOP)
       │
2. GRASP (attribution responsabilités)
       │
3. Defensive (robustesse)
       │
4. GoF Patterns (solutions concrètes)
```

**Règle :** Les principes guident le choix des patterns.

---

## Sources

- [SOLID - Robert C. Martin](https://en.wikipedia.org/wiki/SOLID)
- [GRASP - Craig Larman](https://en.wikipedia.org/wiki/GRASP_(object-oriented_design))
- [Defensive Programming](https://en.wikipedia.org/wiki/Defensive_programming)

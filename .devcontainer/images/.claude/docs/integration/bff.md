# Backend for Frontend (BFF) Pattern

> Une API backend dediee pour chaque type de client (web, mobile, IoT).

---

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                  BACKEND FOR FRONTEND                            │
│                                                                  │
│  Sans BFF:                       Avec BFF:                       │
│                                                                  │
│  ┌────┐ ┌────┐ ┌────┐           ┌────┐ ┌────┐ ┌────┐            │
│  │Web │ │iOS │ │IoT │           │Web │ │iOS │ │IoT │            │
│  └──┬─┘ └─┬──┘ └─┬──┘           └─┬──┘ └─┬──┘ └─┬──┘            │
│     │     │      │                │      │      │               │
│     │     │      │                ▼      ▼      ▼               │
│     │     │      │             ┌─────┐┌─────┐┌─────┐            │
│     │     │      │             │BFF-W││BFF-M││BFF-I│            │
│     │     │      │             └──┬──┘└──┬──┘└──┬──┘            │
│     │     │      │                │      │      │               │
│     └─────┼──────┘                └──────┼──────┘               │
│           │                              │                       │
│           ▼                              ▼                       │
│     ┌──────────┐                   ┌──────────┐                 │
│     │  Generic │                   │ Services │                 │
│     │   API    │                   │          │                 │
│     └──────────┘                   └──────────┘                 │
│                                                                  │
│  Problemes:                     Avantages:                      │
│  - Over-fetching               - Donnees optimisees             │
│  - Under-fetching              - Format adapte                   │
│  - Compromis pour tous         - Moins de round-trips           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Cas d'usage par plateforme

| Client | Besoins specifiques |
|--------|---------------------|
| **Web** | Pagination, SEO metadata, large payloads OK |
| **Mobile** | Payloads compacts, offline support, battery |
| **IoT** | Minimal data, binary protocols, low bandwidth |
| **Watch** | Tres compact, notifications, health data |

---

## Implementation TypeScript

### BFF Web

```typescript
import express from 'express';

interface WebProductList {
  products: Array<{
    id: string;
    name: string;
    description: string;
    price: number;
    images: string[];
    rating: { average: number; count: number };
    availability: string;
    breadcrumb: string[];
  }>;
  pagination: {
    page: number;
    pageSize: number;
    total: number;
    totalPages: number;
  };
  filters: Array<{
    name: string;
    options: string[];
  }>;
  seo: {
    title: string;
    description: string;
    canonicalUrl: string;
  };
}

class WebBFF {
  private readonly app = express();

  constructor() {
    this.setupRoutes();
  }

  private setupRoutes(): void {
    // Liste produits avec toutes les infos pour SEO et UX web
    this.app.get('/products', async (req, res) => {
      const { page = 1, pageSize = 20, category, sort } = req.query;

      // Aggregation de plusieurs services
      const [products, filters, categories] = await Promise.all([
        this.fetchProducts({ page, pageSize, category, sort }),
        this.fetchFilters(category as string),
        this.fetchBreadcrumb(category as string),
      ]);

      const response: WebProductList = {
        products: products.items.map((p) => ({
          id: p.id,
          name: p.name,
          description: p.description, // Full description for web
          price: p.price,
          images: p.images, // All images
          rating: p.rating,
          availability: p.stock > 0 ? 'In Stock' : 'Out of Stock',
          breadcrumb: categories,
        })),
        pagination: {
          page: Number(page),
          pageSize: Number(pageSize),
          total: products.total,
          totalPages: Math.ceil(products.total / Number(pageSize)),
        },
        filters,
        seo: {
          title: `${category} Products - My Store`,
          description: `Browse ${products.total} ${category} products`,
          canonicalUrl: `/products?category=${category}`,
        },
      };

      res.json(response);
    });

    // Detail produit complet pour web
    this.app.get('/products/:id', async (req, res) => {
      const [product, reviews, related] = await Promise.all([
        this.fetchProduct(req.params.id),
        this.fetchReviews(req.params.id, { limit: 10 }),
        this.fetchRelatedProducts(req.params.id, { limit: 6 }),
      ]);

      res.json({
        ...product,
        reviews: reviews.items,
        reviewsSummary: reviews.summary,
        relatedProducts: related,
        seo: {
          title: `${product.name} - My Store`,
          description: product.description.substring(0, 160),
          jsonLd: this.generateProductSchema(product),
        },
      });
    });
  }

  private async fetchProducts(params: any): Promise<any> {
    return fetch(`http://product-service/products?${new URLSearchParams(params)}`).then((r) => r.json());
  }

  private async fetchFilters(category: string): Promise<any> {
    return fetch(`http://filter-service/filters?category=${category}`).then((r) => r.json());
  }

  private async fetchBreadcrumb(category: string): Promise<string[]> {
    return fetch(`http://category-service/breadcrumb/${category}`).then((r) => r.json());
  }

  private async fetchProduct(id: string): Promise<any> {
    return fetch(`http://product-service/products/${id}`).then((r) => r.json());
  }

  private async fetchReviews(productId: string, params: any): Promise<any> {
    return fetch(`http://review-service/products/${productId}/reviews?${new URLSearchParams(params)}`).then((r) => r.json());
  }

  private async fetchRelatedProducts(productId: string, params: any): Promise<any> {
    return fetch(`http://recommendation-service/products/${productId}/related?${new URLSearchParams(params)}`).then((r) => r.json());
  }

  private generateProductSchema(product: any): object {
    return {
      '@context': 'https://schema.org',
      '@type': 'Product',
      name: product.name,
      description: product.description,
      image: product.images[0],
      offers: {
        '@type': 'Offer',
        price: product.price,
        priceCurrency: 'USD',
      },
    };
  }

  start(port: number): void {
    this.app.listen(port);
  }
}
```

---

### BFF Mobile

```typescript
interface MobileProductList {
  products: Array<{
    id: string;
    name: string;
    price: number;
    thumbnail: string;    // Single optimized image
    rating: number;       // Just the number
    inStock: boolean;
  }>;
  nextCursor?: string;    // Cursor pagination for infinite scroll
  hasMore: boolean;
}

class MobileBFF {
  private readonly app = express();

  constructor() {
    this.setupRoutes();
  }

  private setupRoutes(): void {
    // Liste produits optimisee pour mobile
    this.app.get('/products', async (req, res) => {
      const { cursor, limit = 20, category } = req.query;

      const products = await this.fetchProducts({ cursor, limit, category });

      const response: MobileProductList = {
        products: products.items.map((p) => ({
          id: p.id,
          name: p.name.substring(0, 50), // Truncate for mobile
          price: p.price,
          thumbnail: this.getOptimizedImage(p.images[0], 200), // Smaller image
          rating: p.rating.average,
          inStock: p.stock > 0,
        })),
        nextCursor: products.nextCursor,
        hasMore: products.hasMore,
      };

      // Headers pour caching mobile
      res.set({
        'Cache-Control': 'public, max-age=300',
        'ETag': this.generateETag(response),
      });

      res.json(response);
    });

    // Detail produit compact
    this.app.get('/products/:id', async (req, res) => {
      const product = await this.fetchProduct(req.params.id);

      res.json({
        id: product.id,
        name: product.name,
        price: product.price,
        images: product.images.slice(0, 3).map((img) =>
          this.getOptimizedImage(img, 400),
        ),
        description: product.description.substring(0, 300),
        rating: product.rating.average,
        reviewCount: product.rating.count,
        inStock: product.stock > 0,
        // Pas de related products, reviews - lazy load
      });
    });

    // Endpoint separe pour lazy loading
    this.app.get('/products/:id/reviews', async (req, res) => {
      const reviews = await this.fetchReviews(req.params.id, { limit: 5 });
      res.json({
        items: reviews.items.map((r) => ({
          id: r.id,
          rating: r.rating,
          text: r.text.substring(0, 200),
          author: r.author.firstName,
          date: r.createdAt,
        })),
        hasMore: reviews.hasMore,
      });
    });
  }

  private getOptimizedImage(url: string, width: number): string {
    // CDN image resizing
    return `${url}?w=${width}&format=webp&quality=80`;
  }

  private generateETag(data: any): string {
    return `"${Buffer.from(JSON.stringify(data)).toString('base64').substring(0, 20)}"`;
  }

  private async fetchProducts(params: any): Promise<any> {
    return fetch(`http://product-service/products?${new URLSearchParams(params)}`).then((r) => r.json());
  }

  private async fetchProduct(id: string): Promise<any> {
    return fetch(`http://product-service/products/${id}`).then((r) => r.json());
  }

  private async fetchReviews(productId: string, params: any): Promise<any> {
    return fetch(`http://review-service/products/${productId}/reviews?${new URLSearchParams(params)}`).then((r) => r.json());
  }

  start(port: number): void {
    this.app.listen(port);
  }
}
```

---

### BFF IoT

```typescript
interface IoTProductData {
  i: string;   // id (abbreviated)
  p: number;   // price
  s: 0 | 1;    // stock (boolean as number)
}

class IoTBFF {
  private readonly app = express();

  constructor() {
    this.setupRoutes();
  }

  private setupRoutes(): void {
    // Minimal data for constrained devices
    this.app.get('/p', async (req, res) => {
      const products = await this.fetchProducts({ limit: 10 });

      const response: IoTProductData[] = products.items.map((p) => ({
        i: p.id,
        p: Math.round(p.price * 100), // Cents, integer
        s: p.stock > 0 ? 1 : 0,
      }));

      // Binary-friendly response
      res.set({
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=3600',
      });

      res.json(response);
    });

    // Price check only (for barcode scanners)
    this.app.get('/p/:sku/price', async (req, res) => {
      const product = await this.fetchProductBySku(req.params.sku);
      res.json({ p: Math.round(product.price * 100) });
    });
  }

  private async fetchProducts(params: any): Promise<any> {
    return fetch(`http://product-service/products?${new URLSearchParams(params)}`).then((r) => r.json());
  }

  private async fetchProductBySku(sku: string): Promise<any> {
    return fetch(`http://product-service/products/sku/${sku}`).then((r) => r.json());
  }

  start(port: number): void {
    this.app.listen(port);
  }
}
```

---

## GraphQL Federation comme alternative

```typescript
import { ApolloServer } from '@apollo/server';
import { buildSubgraphSchema } from '@apollo/subgraph';
import { gql } from 'graphql-tag';

// Chaque BFF peut exposer un schema GraphQL
const webTypeDefs = gql`
  type Product {
    id: ID!
    name: String!
    description: String!
    price: Float!
    images: [String!]!
    rating: Rating!
    reviews(limit: Int): [Review!]!
    relatedProducts: [Product!]!
    seo: SEO!
  }

  type Query {
    products(page: Int, category: String): ProductList!
    product(id: ID!): Product
  }
`;

const mobileTypeDefs = gql`
  type Product {
    id: ID!
    name: String!
    price: Float!
    thumbnail: String!
    rating: Float!
    inStock: Boolean!
  }

  type Query {
    products(cursor: String, limit: Int): ProductConnection!
    product(id: ID!): Product
  }
`;

// Le client demande exactement ce dont il a besoin
```

---

## Quand utiliser

- Plusieurs types de clients (web, mobile, desktop)
- Besoins tres differents par plateforme
- Optimisation reseau critique (mobile)
- Equipes frontend independantes

---

## Quand NE PAS utiliser

- Un seul type de client
- API RESTful simple suffit
- Equipe trop petite pour maintenir plusieurs BFFs
- Clients avec besoins similaires

---

## Lie a

| Pattern | Relation |
|---------|----------|
| [API Gateway](api-gateway.md) | BFF derriere le gateway |
| GraphQL | Alternative avec un seul endpoint |
| [Sidecar](sidecar.md) | Fonctions partagees entre BFFs |
| CQRS | Read models par client |

---

## Sources

- [Sam Newman - BFF Pattern](https://samnewman.io/patterns/architectural/bff/)
- [Microsoft - BFF Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/backends-for-frontends)
- [Netflix - BFF at Scale](https://netflixtechblog.com/optimizing-the-netflix-api-5c9ac715cf19)

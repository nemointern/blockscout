# BENS (Blockscout ENS) Integration for Namoshi

This document describes the integration of Namoshi Name Service with CitreaScan using BENS (Blockscout ENS).

## Overview

Namoshi is a native naming service for the Citrea blockchain, forked from ENS. This integration enables:

- **Address Resolution**: Display `.btc` and `.citrea` names next to addresses throughout the block explorer
- **Domain Search**: Search for domains in the block explorer search bar
- **Domain Pages**: View detailed domain information, history, and resolver data
- **Reverse Resolution**: Lookup domains owned by or pointing to specific addresses

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Graph Node (indexes Namoshi subgraph)                          │
│  - Entities: Domain, Account, Resolver, Registration            │
│  - Events: NewOwner, Transfer, NameRegistered, etc.             │
└───────────────────────────┬─────────────────────────────────────┘
                             │ PostgreSQL
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  BENS Server (Rust microservice)                                 │
│  - Reads from Graph Node PostgreSQL database                     │
│  - Implements HTTP API for domain queries                        │
│  - Supports multiple protocols (Namoshi in our case)             │
└───────────────────────────┬─────────────────────────────────────┘
                             │ HTTP API (port 8050)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  CitreaScan Blockscout (Elixir/Phoenix)                         │
│  - Address metadata preloading with ENS names                    │
│  - Domain search integration                                     │
│  - Batch address → name resolution                               │
└─────────────────────────────────────────────────────────────────┘
```

## Namoshi Configuration

### Contracts (Citrea Mainnet - Chain ID: 4114)

| Contract | Address |
|----------|---------|
| ENS Registry | `0x9fA2e2370dF8014EE485172bF79d10D6756034A8` |
| Base Registrar | `0xDB814a8C706e040F6615F37509ae3a38721577e8` |
| ETH Registrar Controller | `0xa08728ca65b6b980059dB463AD2714dfffa848cf` |
| Name Wrapper | `0xd141a197c8A68D9175C201229ae3bf5a7972e8b1` |
| Public Resolver | `0x716342C3231A50B55522F16f55ed76B5Bf29df76` |
| Universal Resolver | `0xc5ed1fa34ad1f23f0cd2e36db288290488b1b493` |

### Top-Level Domains (TLDs)

- `.btc` - Primary TLD
- `.citrea` - Secondary TLD

### Subgraph

The Namoshi subgraph indexes all domain registrations, transfers, and resolver updates from block `2534703` on Citrea mainnet.

**Entities**:
- `Domain` - Primary entity with name, owner, resolver, TTL, etc.
- `Account` - Addresses that own domains
- `Resolver` - Resolver contracts with address records, text records, etc.
- `Registration` - Registration events with cost and expiry
- `WrappedDomain` - Name Wrapper data

## BENS Configuration

The BENS service is configured via `docker-compose/bens-config.json`:

```json
{
  "subgraphs_reader": {
    "networks": {
      "4114": {
        "blockscout": {
          "url": "http://backend:4000"
        },
        "use_protocols": ["namoshi"],
        "rpc_url": "https://rpc.mainnet.citrea.xyz"
      }
    },
    "protocols": {
      "namoshi": {
        "network_id": 4114,
        "subgraph_name": "namoshi-subgraph",
        "tld_list": ["btc", "citrea"],
        "address_resolve_technique": "all_domains",
        "specific": {
          "type": "ens_like",
          "native_token_contract": "0xDB814a8C706e040F6615F37509ae3a38721577e8",
          "registry_contract": "0x9fA2e2370dF8014EE485172bF79d10D6756034A8"
        }
      }
    }
  }
}
```

## Environment Variables

Add to `docker-compose/envs/common-blockscout.env`:

```bash
# BENS (Blockscout ENS) Configuration
MICROSERVICE_BENS_URL=http://bens:8050
MICROSERVICE_BENS_ENABLED=true

# BENS Database (points to Graph Node PostgreSQL)
BENS_DATABASE_URL=postgresql://graph-node:let-me-in@host.docker.internal:5432/graph-node
BENS_RUST_LOG=info
BENS_CONFIG_PATH=./bens-config.json
```

## Docker Compose Integration

Add to `docker-compose/docker-compose.yml`:

```yaml
services:
  bens:
    depends_on:
      - backend
    extends:
      file: ./services/bens.yml
      service: bens
```

## API Endpoints

Once BENS is running, the following endpoints are available:

### Health Check
```
GET http://localhost:8050/health
```

### Get Domain by Name
```
GET http://localhost:8050/api/v1/4114/domains/{name}

Example: GET http://localhost:8050/api/v1/4114/domains/vitalik.btc
```

### Get Address Info (Primary Domain)
```
GET http://localhost:8050/api/v1/4114/addresses/{address_hash}

Example: GET http://localhost:8050/api/v1/4114/addresses/0x123...
```

### Domain Lookup (Search)
```
GET http://localhost:8050/api/v1/4114/domains:lookup?name={search_term}

Example: GET http://localhost:8050/api/v1/4114/domains:lookup?name=vitalik
```

### Batch Resolve Names
```
POST http://localhost:8050/api/v1/4114/addresses:batch-resolve-names
Content-Type: application/json

{
  "addresses": ["0x123...", "0x456..."]
}
```

### Get Protocols
```
GET http://localhost:8050/api/v1/4114/protocols
```

## Testing

See [LOCAL_TESTING.md](./LOCAL_TESTING.md) for complete local testing instructions.

Quick test:

```bash
# Check BENS health
curl http://localhost:8050/health

# Query protocols
curl http://localhost:8050/api/v1/4114/protocols

# Search for a domain
curl "http://localhost:8050/api/v1/4114/domains:lookup?name=test"
```

## Integration Points in Blockscout

BENS integrates with Blockscout in the following areas:

1. **Address Display** - ENS names appear next to addresses in:
   - Transaction lists
   - Block details
   - Token transfers
   - Internal transactions
   - Event logs

2. **Search** - Domain search in the main search bar:
   - Type a domain name (e.g., `vitalik.btc`)
   - See matching domains and their resolved addresses

3. **Address Pages** - Primary domain displayed on address pages

4. **Metadata Preloader** - Batch resolution of addresses to names for efficiency

## Deployment

### Local Development

1. Start Graph Node with Namoshi subgraph:
   ```bash
   cd namoshi-subgraph
   docker-compose up -d
   bun run create-local
   bun run deploy-local
   ```

2. Start CitreaScan with BENS:
   ```bash
   cd CitreaScan/blockscout/docker-compose
   docker-compose up -d
   ```

### Production

For production deployment:

1. Ensure Graph Node is running with the Namoshi subgraph fully synced
2. Update `bens-config.json` with production URLs and credentials
3. Set production environment variables in `common-blockscout.env`
4. Deploy BENS service
5. Deploy/restart Blockscout backend to pick up BENS configuration

## Troubleshooting

### BENS not connecting to Graph Node

Check that:
- Graph Node PostgreSQL is accessible at the configured URL
- The database name matches (`graph-node`)
- Credentials are correct (`graph-node:let-me-in`)

### No domains returned

Check that:
- Namoshi subgraph is deployed and synced
- Subgraph name in `bens-config.json` matches deployed name
- Graph Node has indexed blocks from the start block (2534703)

### Names not showing in Blockscout

Check that:
- `MICROSERVICE_BENS_ENABLED=true` is set
- `MICROSERVICE_BENS_URL` points to BENS service
- BENS service is healthy (`/health` endpoint returns 200)
- Domain exists and resolves to the address in question

## References

- [Namoshi Contracts](https://github.com/CitreaScan/namoshi-contracts)
- [Namoshi Subgraph](https://github.com/CitreaScan/namoshi-subgraph)
- [Blockscout BENS Documentation](https://github.com/blockscout/blockscout-rs/tree/main/blockscout-ens)
- [CitreaScan](https://explorer.mainnet.citrea.xyz)

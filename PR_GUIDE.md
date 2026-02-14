# PR Guide: BENS Integration for Namoshi

## Overview

This PR adds BENS (Blockscout ENS) integration to enable Namoshi Name Service support in CitreaScan. Namoshi is a native naming service for Citrea with `.btc` and `.citrea` TLDs.

## Changes

### 1. New Files

#### `docker-compose/services/bens.yml`
- Docker Compose service definition for BENS server
- Configures connection to Graph Node PostgreSQL database
- Exposes HTTP API on port 8050
- Includes health checks

#### `docker-compose/bens-config.json`
- BENS protocol configuration for Namoshi
- Defines network 4114 (Citrea mainnet)
- Specifies Namoshi contract addresses and TLDs
- Configures domain resolution strategy

#### `BENS_INTEGRATION.md`
- Comprehensive documentation on BENS integration
- Architecture overview
- Contract addresses and configuration details
- API endpoints reference
- Troubleshooting guide

#### `LOCAL_TESTING.md`
- Step-by-step guide for local testing
- Prerequisites and setup instructions
- Troubleshooting common issues
- Testing checklist

### 2. Modified Files

#### `docker-compose/docker-compose.yml`
- Added `bens` service after `user-ops-indexer`
- Service depends on `backend` and extends `services/bens.yml`

#### `docker-compose/envs/common-blockscout.env`
- Enabled BENS integration:
  - `MICROSERVICE_BENS_URL=http://bens:8050`
  - `MICROSERVICE_BENS_ENABLED=true`

## What is BENS?

BENS (Blockscout ENS) is a microservice that provides ENS-like name service integration for Blockscout. It:

1. Reads indexed data from a Graph Node PostgreSQL database
2. Provides HTTP API for domain queries
3. Supports multiple name service protocols (ENS, Namoshi, etc.)
4. Enables address → name resolution throughout the block explorer

## What is Namoshi?

Namoshi is an ENS fork for the Citrea blockchain featuring:

- **TLDs**: `.btc` and `.citrea`
- **Network**: Citrea mainnet (Chain ID: 4114)
- **Contracts**: ENS Registry, Base Registrar, Name Wrapper, Public Resolver, Universal Resolver
- **Subgraph**: Indexes all domain events from block 2534703

## Features Enabled

With this integration, CitreaScan will:

1. **Display domain names next to addresses** throughout the UI:
   - Transaction lists
   - Block details
   - Token transfers
   - Event logs

2. **Enable domain search**:
   - Search for `.btc` and `.citrea` domains
   - Find addresses by domain name
   - View domain details and history

3. **Show primary domains** on address pages

4. **Batch resolve addresses** for performance optimization

## Prerequisites

### External Dependencies

This integration requires:

1. **Graph Node** running with Namoshi subgraph
   - Repository: https://github.com/CitreaScan/namoshi-subgraph
   - Must be deployed and syncing from block 2534703
   - Exposes PostgreSQL database for BENS to read

2. **Namoshi Contracts** deployed on Citrea mainnet
   - Repository: https://github.com/CitreaScan/namoshi-contracts
   - ENS Registry: `0x9fA2e2370dF8014EE485172bF79d10D6756034A8`
   - Base Registrar: `0xDB814a8C706e040F6615F37509ae3a38721577e8`

### Configuration Requirements

- BENS needs access to Graph Node's PostgreSQL database
- Database connection: `postgresql://graph-node:let-me-in@host.docker.internal:5432/graph-node`
- Network access: BENS (port 8050) must be accessible from Blockscout backend

## Testing

### Local Testing

Follow the [LOCAL_TESTING.md](./LOCAL_TESTING.md) guide for complete instructions.

Quick test:

```bash
# 1. Start Graph Node with Namoshi subgraph
cd /path/to/namoshi-subgraph
docker-compose up -d
bun run create-local
bun run deploy-local

# 2. Start CitreaScan with BENS
cd /path/to/CitreaScan/blockscout/docker-compose
docker-compose up -d

# 3. Test BENS API
curl http://localhost:8050/health
curl http://localhost:8050/api/v1/4114/protocols

# 4. Test in Blockscout UI
# Open http://localhost and search for a domain
```

### CI/CD Considerations

- BENS service should be deployed alongside Blockscout
- Requires Graph Node to be running and healthy
- Health check endpoint: `http://bens:8050/health`
- Service is optional - Blockscout will work without it, but domain features will be disabled

## Deployment Steps

### Production Deployment

1. **Deploy Graph Node** with Namoshi subgraph (if not already running)
   ```bash
   cd namoshi-subgraph
   # Update docker-compose for production
   docker-compose up -d
   ```

2. **Configure BENS** for production
   - Update `bens-config.json` with production URLs
   - Set production database credentials
   - Configure proper monitoring

3. **Deploy/Update Blockscout**
   ```bash
   cd CitreaScan/blockscout/docker-compose
   docker-compose pull
   docker-compose up -d
   ```

4. **Verify Integration**
   - Check BENS health: `curl http://bens:8050/health`
   - Check protocols: `curl http://bens:8050/api/v1/4114/protocols`
   - Test domain search in UI

### Environment Variables

Required in production:

```bash
# Blockscout
MICROSERVICE_BENS_URL=http://bens:8050
MICROSERVICE_BENS_ENABLED=true
CHAIN_ID=4114

# BENS (via bens.yml service)
BENS_DATABASE_URL=postgresql://graph-node:PASSWORD@postgres-host:5432/graph-node
BENS_RUST_LOG=info
BENS_CONFIG_PATH=./bens-config.json
```

## Architecture

```
┌──────────────────────────────────────────┐
│  Graph Node                               │
│  ┌────────────────────────────────────┐  │
│  │ Namoshi Subgraph                   │  │
│  │ - Domains, Registrations, etc.     │  │
│  └────────────────────────────────────┘  │
│              │ PostgreSQL                 │
└──────────────┼────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  BENS Server (Rust)                       │
│  ┌────────────────────────────────────┐  │
│  │ HTTP API (port 8050)               │  │
│  │ - Domain lookup                    │  │
│  │ - Address resolution               │  │
│  │ - Batch queries                    │  │
│  └────────────────────────────────────┘  │
└──────────────┼────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  CitreaScan Blockscout                    │
│  ┌────────────────────────────────────┐  │
│  │ BENS Client (Elixir)               │  │
│  │ - Explorer.MicroserviceInterfaces  │  │
│  │   .BENS                            │  │
│  │ - Search integration               │  │
│  │ - Metadata preloader               │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

## API Examples

### Get Protocols

```bash
curl http://localhost:8050/api/v1/4114/protocols
```

Response:
```json
{
  "protocols": [
    {
      "id": "namoshi",
      "title": "Namoshi Name Service",
      "short_name": "Namoshi",
      "description": "Native naming service for Citrea network",
      "tld_list": ["btc", "citrea"],
      "is_active": true
    }
  ]
}
```

### Search Domains

```bash
curl "http://localhost:8050/api/v1/4114/domains:lookup?name=vitalik"
```

### Get Address Info

```bash
curl http://localhost:8050/api/v1/4114/addresses/0x123...
```

### Batch Resolve

```bash
curl -X POST http://localhost:8050/api/v1/4114/addresses:batch-resolve-names \
  -H "Content-Type: application/json" \
  -d '{"addresses": ["0x123...", "0x456..."]}'
```

## Performance Considerations

- **Caching**: BENS reads from PostgreSQL; consider adding Redis caching if needed
- **Database Load**: Graph Node PostgreSQL handles both indexing and BENS queries
- **API Rate Limiting**: Consider rate limiting on BENS API in production
- **Batch Queries**: Blockscout uses batch queries for efficient address resolution

## Monitoring

Recommended monitoring:

1. **BENS Health**
   - Endpoint: `/health`
   - Should return 200 with `{"status":"SERVING"}`

2. **Database Connection**
   - Monitor PostgreSQL connection pool
   - Watch for connection timeouts

3. **API Response Times**
   - Track latency for domain lookups
   - Monitor batch query performance

4. **Subgraph Sync Status**
   - Ensure Graph Node is synced
   - Monitor for indexing errors

## Rollback Plan

If issues arise:

1. **Disable BENS** in Blockscout:
   ```bash
   # Set in common-blockscout.env
   MICROSERVICE_BENS_ENABLED=false
   
   # Restart backend
   docker-compose restart backend
   ```

2. **Stop BENS service**:
   ```bash
   docker-compose stop bens
   ```

Blockscout will continue to function without domain name features.

## Security Considerations

- BENS has read-only access to Graph Node database
- No write operations performed by BENS
- API is public (consider authentication in production if needed)
- Database credentials should be properly secured

## Future Enhancements

Potential improvements:

1. **Caching Layer**: Add Redis for frequently accessed domains
2. **CDN**: Cache domain lookups at CDN level
3. **Analytics**: Track domain usage and search patterns
4. **Multiple Protocols**: Support additional name services if needed
5. **Reverse Resolution**: Enhanced reverse lookup features

## References

- [Blockscout BENS Documentation](https://github.com/blockscout/blockscout-rs/tree/main/blockscout-ens)
- [Namoshi Contracts](https://github.com/CitreaScan/namoshi-contracts)
- [Namoshi Subgraph](https://github.com/CitreaScan/namoshi-subgraph)
- [ENS Documentation](https://docs.ens.domains/)

## Questions & Support

For questions or issues:

1. Check [LOCAL_TESTING.md](./LOCAL_TESTING.md) troubleshooting section
2. Review [BENS_INTEGRATION.md](./BENS_INTEGRATION.md) documentation
3. Check BENS logs: `docker-compose logs bens`
4. Check Blockscout logs: `docker-compose logs backend | grep -i bens`

## Checklist for Reviewers

- [ ] Service definitions are properly configured
- [ ] Environment variables are set correctly
- [ ] Documentation is clear and complete
- [ ] BENS config matches Namoshi contract addresses
- [ ] Network ID (4114) is correct throughout
- [ ] Health checks are configured
- [ ] Dependencies are properly ordered
- [ ] No credentials hardcoded in config files
- [ ] Local testing guide is accurate
- [ ] PR description explains the integration clearly

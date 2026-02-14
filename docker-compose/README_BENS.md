# BENS Integration for Namoshi

This directory contains the BENS (Blockscout ENS) integration for Namoshi Name Service.

## What is BENS?

BENS is a microservice that provides ENS-like name service integration for Blockscout. It enables:
- Domain name display next to addresses
- Domain search functionality
- Address → name resolution
- Domain details and history

## Files in This Directory

- `services/bens.yml` - Docker Compose service definition for BENS
- `bens-config.json` - BENS protocol configuration for Namoshi
- `envs/common-blockscout.env` - Environment variables (includes BENS settings)

## Quick Start

### Prerequisites

1. **Graph Node** with Namoshi subgraph must be running
   - See: https://github.com/CitreaScan/namoshi-subgraph

2. **Namoshi contracts** deployed on Citrea mainnet
   - Chain ID: 4114
   - See: https://github.com/CitreaScan/namoshi-contracts

### Start CitreaScan with BENS

```bash
# From this directory
docker-compose up -d
```

The BENS service will automatically start with the other services.

### Verify BENS is Running

```bash
# Health check
curl http://localhost:8050/health

# Get protocols (should return Namoshi)
curl http://localhost:8050/api/v1/4114/protocols | jq

# Test domain search
curl "http://localhost:8050/api/v1/4114/domains:lookup?name=test" | jq
```

## Configuration

### Environment Variables

Set in `envs/common-blockscout.env`:

```bash
# BENS Configuration
MICROSERVICE_BENS_URL=http://bens:8050
MICROSERVICE_BENS_ENABLED=true

# Chain ID (must match Citrea mainnet)
CHAIN_ID=4114
```

### BENS Protocol Configuration

Edit `bens-config.json` to modify:
- Network settings (RPC URL, Blockscout URL)
- Protocol settings (TLDs, contract addresses)
- Subgraph name and network ID

## Testing

### Local Testing

For complete local testing instructions, see:
- `../LOCAL_TESTING.md` - Full testing guide
- `../test-bens.sh` - Automated test script

Quick test:

```bash
cd ..
./test-bens.sh
```

### Manual Testing

```bash
# Test BENS endpoints
curl http://localhost:8050/health
curl http://localhost:8050/api/v1/4114/protocols
curl "http://localhost:8050/api/v1/4114/domains:lookup?name=test"

# Test in Blockscout UI
# Open http://localhost and search for a domain
```

## Architecture

```
Graph Node (PostgreSQL)
         ↓
    BENS Server (port 8050)
         ↓
CitreaScan Blockscout Backend
         ↓
    Frontend UI
```

## Troubleshooting

### BENS Service Won't Start

Check logs:
```bash
docker-compose logs bens
```

Common issues:
- PostgreSQL not accessible (check Graph Node is running)
- Config file not found (check `bens-config.json` exists)
- Port 8050 already in use

### No Domains Returned

Verify:
1. Graph Node is running and synced
2. Namoshi subgraph is deployed
3. Subgraph name in config matches deployed name
4. Domains exist in the subgraph

Query subgraph directly:
```bash
curl http://localhost:8000/subgraphs/name/namoshi-subgraph/graphql \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"query":"{ domains(first: 5) { name owner { id } } }"}'
```

### Names Not Showing in Blockscout

Check:
1. BENS is enabled: `MICROSERVICE_BENS_ENABLED=true`
2. BENS URL is correct: `MICROSERVICE_BENS_URL=http://bens:8050`
3. BENS service is healthy: `curl http://localhost:8050/health`
4. Backend can reach BENS:
   ```bash
   docker-compose exec backend curl http://bens:8050/health
   ```

Restart backend:
```bash
docker-compose restart backend
```

## Documentation

Full documentation:
- `../BENS_INTEGRATION.md` - Technical documentation
- `../LOCAL_TESTING.md` - Testing guide
- `../PR_GUIDE.md` - PR preparation guide

## Support

For issues:
1. Check logs: `docker-compose logs bens`
2. Verify Graph Node is running
3. Test BENS API directly
4. Check Blockscout backend logs: `docker-compose logs backend | grep -i bens`

## Links

- BENS Documentation: https://github.com/blockscout/blockscout-rs/tree/main/blockscout-ens
- Namoshi Contracts: https://github.com/CitreaScan/namoshi-contracts
- Namoshi Subgraph: https://github.com/CitreaScan/namoshi-subgraph
- Citrea Network: https://citrea.xyz

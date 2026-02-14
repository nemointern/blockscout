# Local Testing Guide for BENS Integration

This guide will help you test the Namoshi BENS integration with CitreaScan locally.

## Prerequisites

- Docker and Docker Compose
- Bun (for Namoshi subgraph deployment)
- Git

## Architecture Overview

For local testing, we'll run:

1. **Graph Node** - Indexes Namoshi events from Citrea mainnet
2. **PostgreSQL** - Stores indexed data
3. **IPFS** - Required by Graph Node
4. **BENS Server** - Reads from PostgreSQL and serves domain data
5. **CitreaScan Blockscout** - Block explorer with BENS integration

## Step 1: Start Graph Node and Deploy Namoshi Subgraph

### 1.1 Navigate to Namoshi Subgraph

```bash
cd /path/to/namoshi-subgraph
```

**Note**: Replace `/path/to/namoshi-subgraph` with your actual path to the Namoshi subgraph repository.

### 1.2 Start Graph Node Stack

```bash
docker-compose up -d
```

This starts:
- PostgreSQL (port 5432)
- IPFS (port 5001)
- Graph Node (ports 8000, 8001, 8020, 8030, 8040)

### 1.3 Wait for Services

```bash
# Wait for Graph Node to be ready
docker-compose logs -f graph-node

# Wait for: "Starting JSON-RPC admin server at..."
# Press Ctrl+C once ready
```

### 1.4 Deploy Subgraph

```bash
# Create the subgraph
bun run create-local

# Deploy the subgraph
bun run deploy-local
```

### 1.5 Verify Subgraph Deployment

```bash
# Check subgraph status
curl http://localhost:8000/subgraphs/name/namoshi-subgraph/graphql \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}'
```

Expected response:
```json
{
  "data": {
    "_meta": {
      "block": {
        "number": <current_block_number>
      }
    }
  }
}
```

### 1.6 Wait for Sync

The subgraph starts indexing from block `2534703`. You can monitor progress:

```bash
# Check current block
curl http://localhost:8000/subgraphs/name/namoshi-subgraph/graphql \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } } }"}'

# Check indexed domains
curl http://localhost:8000/subgraphs/name/namoshi-subgraph/graphql \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"query": "{ domains(first: 5) { id name owner { id } } }"}'
```

## Step 2: Configure CitreaScan for BENS

### 2.1 Navigate to CitreaScan

```bash
cd /path/to/CitreaScan/blockscout
```

**Note**: Replace `/path/to/CitreaScan/blockscout` with your actual path to the CitreaScan repository.

### 2.2 Update Environment Variables

Edit `docker-compose/envs/common-blockscout.env`:

```bash
# Uncomment and set BENS configuration
MICROSERVICE_BENS_URL=http://bens:8050
MICROSERVICE_BENS_ENABLED=true

# Ensure CHAIN_ID matches Citrea
CHAIN_ID=4114
```

### 2.3 Verify BENS Config File

The `docker-compose/bens-config.json` should already be created. Verify it contains:

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

### 2.4 Add BENS to Docker Compose

Edit `docker-compose/docker-compose.yml` and add the BENS service:

```yaml
services:
  # ... existing services ...

  bens:
    depends_on:
      - backend
    extends:
      file: ./services/bens.yml
      service: bens
```

## Step 3: Start BENS Service

### 3.1 Start BENS Separately First (for testing)

```bash
cd /path/to/CitreaScan/blockscout/docker-compose

# Start BENS with local config
docker run --platform linux/amd64 \
  --rm \
  --name bens \
  -p 8050:8050 \
  --add-host=host.docker.internal:host-gateway \
  -e BENS__DATABASE__CONNECT__URL=postgresql://graph-node:let-me-in@host.docker.internal:5432/graph-node \
  -e BENS__DATABASE__CREATE_DATABASE=false \
  -e BENS__DATABASE__RUN_MIGRATIONS=true \
  -e BENS__SERVER__HTTP__ENABLED=true \
  -e BENS__SERVER__HTTP__ADDR=0.0.0.0:8050 \
  -e RUST_LOG=info \
  -e BENS__CONFIG=/app/config.json \
  -v "$(pwd)/bens-config.json:/app/config.json:ro" \
  ghcr.io/blockscout/bens:latest
```

### 3.2 Verify BENS is Running

```bash
# Health check
curl http://localhost:8050/health

# Should return: {"status":"SERVING"}
```

### 3.3 Test BENS API

```bash
# Get protocols
curl http://localhost:8050/api/v1/4114/protocols | jq

# Expected response:
# {
#   "protocols": [
#     {
#       "id": "namoshi",
#       "title": "Namoshi Name Service",
#       "short_name": "Namoshi",
#       "tld_list": ["btc", "citrea"],
#       ...
#     }
#   ]
# }

# Search for domains
curl "http://localhost:8050/api/v1/4114/domains:lookup?name=test" | jq

# Get domain info (replace with actual domain)
curl http://localhost:8050/api/v1/4114/domains/vitalik.btc | jq
```

## Step 4: Start CitreaScan Blockscout

### 4.1 Start Full Stack

```bash
cd /path/to/CitreaScan/blockscout/docker-compose

# Stop BENS standalone if running
docker stop bens

# Start full stack with BENS
docker-compose up -d
```

### 4.2 Wait for Services

```bash
# Check logs
docker-compose logs -f backend

# Wait for: "Running BlockScoutWeb.Endpoint with..."
```

### 4.3 Access Blockscout

Open your browser to:
- **Frontend**: http://localhost
- **API**: http://localhost/api/v2

## Step 5: Test BENS Integration in Blockscout

### 5.1 Test Domain Search

1. Open http://localhost
2. Use the search bar
3. Type a domain name (e.g., `test.btc` or `vitalik.citrea`)
4. You should see matching domains in search results

### 5.2 Test Address Resolution

1. Find a transaction with an address that has a Namoshi domain
2. The domain name should appear next to the address
3. Click on the address to see the primary domain on the address page

### 5.3 Test API Endpoints

```bash
# Search via Blockscout API
curl "http://localhost/api/v2/search?q=test.btc" | jq

# Get address with ENS info
curl "http://localhost/api/v2/addresses/0x..." | jq
```

## Troubleshooting

### Issue: BENS can't connect to PostgreSQL

**Symptoms**: BENS logs show connection errors

**Solutions**:
1. Verify Graph Node PostgreSQL is running:
   ```bash
   docker ps | grep postgres
   ```

2. Test connection:
   ```bash
   docker run --rm -it --add-host=host.docker.internal:host-gateway postgres:14 \
     psql postgresql://graph-node:let-me-in@host.docker.internal:5432/graph-node -c "\dt"
   ```

3. Check if subgraph tables exist:
   ```bash
   # Should see tables like sgd1.domain, sgd1.account, etc.
   ```

### Issue: No domains returned from BENS

**Symptoms**: BENS API returns empty results

**Solutions**:
1. Verify subgraph is deployed:
   ```bash
   curl http://localhost:8000/subgraphs/name/namoshi-subgraph/graphql \
     -X POST -H "Content-Type: application/json" \
     -d '{"query": "{ domains(first: 10) { id name } }"}'
   ```

2. Check subgraph name matches config:
   - In `bens-config.json`: `"subgraph_name": "namoshi-subgraph"`
   - Deployed name should be `namoshi-subgraph`

3. Verify domains exist in the subgraph:
   ```bash
   curl http://localhost:8000/subgraphs/name/namoshi-subgraph/graphql \
     -X POST -H "Content-Type: application/json" \
     -d '{"query": "{ domains(first: 1) { id name owner { id } } }"}'
   ```

### Issue: Names not showing in Blockscout

**Symptoms**: BENS works but Blockscout doesn't show domain names

**Solutions**:
1. Check BENS is enabled in Blockscout:
   ```bash
   docker-compose exec backend env | grep BENS
   # Should show:
   # MICROSERVICE_BENS_ENABLED=true
   # MICROSERVICE_BENS_URL=http://bens:8050
   ```

2. Check BENS URL is reachable from backend:
   ```bash
   docker-compose exec backend curl http://bens:8050/health
   ```

3. Check Blockscout logs for BENS errors:
   ```bash
   docker-compose logs backend | grep -i bens
   ```

4. Restart backend to pick up config changes:
   ```bash
   docker-compose restart backend
   ```

### Issue: Subgraph not syncing

**Symptoms**: Subgraph stuck at old block or not indexing

**Solutions**:
1. Check Graph Node logs:
   ```bash
   cd /path/to/namoshi-subgraph
   docker-compose logs -f graph-node
   ```

2. Look for errors related to:
   - RPC connection issues
   - Block range limits (already tuned for Citrea)
   - Contract ABI mismatches

3. Check RPC is responding:
   ```bash
   curl -X POST https://rpc.mainnet.citrea.xyz \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
   ```

4. Restart Graph Node:
   ```bash
   docker-compose restart graph-node
   ```

## Testing Checklist

- [ ] Graph Node started successfully
- [ ] Namoshi subgraph deployed
- [ ] Subgraph is syncing (blocks increasing)
- [ ] Domains visible in subgraph GraphQL
- [ ] BENS server started successfully
- [ ] BENS health check passes
- [ ] BENS protocols endpoint returns Namoshi
- [ ] BENS domain lookup returns results
- [ ] CitreaScan Blockscout started
- [ ] BENS enabled in Blockscout env
- [ ] Domain search works in Blockscout UI
- [ ] Domain names appear next to addresses
- [ ] Address page shows primary domain

## Clean Up

To stop all services:

```bash
# Stop CitreaScan
cd /path/to/CitreaScan/blockscout/docker-compose
docker-compose down

# Stop Graph Node
cd /path/to/namoshi-subgraph
docker-compose down

# Optional: Remove data volumes
docker-compose down -v
```

## Production Deployment Notes

For production:

1. **Graph Node**: Deploy to a dedicated server with SSD storage
2. **BENS**: Use environment-specific config with production URLs
3. **Blockscout**: Set production RPC URLs and credentials
4. **Monitoring**: Add health checks and alerting for all services
5. **Backups**: Regular PostgreSQL backups for Graph Node database

## Next Steps

- Test with various domain queries
- Monitor BENS performance under load
- Configure caching if needed
- Set up monitoring and alerts
- Document any Namoshi-specific behavior

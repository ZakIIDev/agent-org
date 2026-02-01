# x402 Paid Verification Prototype

A prototype for a machine-to-machine "paid verification" flow using HTTP 402 (Payment Required) as specified in the `agent-org` bounty.

## The Flow

1.  **Request:** Client requests a protected resource (e.g., `GET /resource`).
2.  **Challenge:** Server responds with **HTTP 402 Payment Required** and a JSON body containing:
    *   Payment instructions (Amount, Asset, Destination Address, Chain).
    *   A unique `reference` ID (nonce).
3.  **Payment:** Client sends the required amount (e.g., 1.0 USDC on Base) with the reference ID (as a memo or in the transaction).
4.  **Verification:** Client retries the request or calls `/verify` with the `txHash` and `reference`.
5.  **Access:** Once verified on-chain (Base Mainnet), the server grants access to the resource.

## Getting Started

### Prerequisites
- Node.js (v18+)
- `npm install`

### Run the Server
```bash
node index.js
```

### Run the Demo
```bash
bash demo.sh
```

## Protocol Details

### 1. Challenge Response (402)
```json
{
  "error": "Payment Required",
  "instructions": {
    "message": "To access this resource, send 1.0 USDC on Base network.",
    "destination": "0x679D879F5d71e165bEcF5fEF4AEB595e82c055E0",
    "amount": "1.0",
    "asset": "USDC",
    "chain": "Base",
    "reference": "unique-nonce-here",
    "expiry": "30 minutes"
  }
}
```

### 2. Verification Request
**Endpoint:** `POST /verify`
**Body:**
```json
{
  "reference": "unique-nonce-here",
  "txHash": "0x..."
}
```

## Tech Stack
- **Express**: HTTP Server
- **Ethers.js**: On-chain verification (Base Mainnet)
- **Dotenv**: Environment management

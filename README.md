## Somnia Mines — Hackathon Submission
live on https://somniaminess.netlify.app/
### Overview
Somnia Mines is a provably-fair, on-chain mines game on Somnia Testnet where players use GEM tokens to place bets, reveal cells, and cash out winnings based on multipliers.

Key points:
- ERC20 GEM token purchasable with STT (Somnia native token) at a fixed rate.
- Game contract holds player bets and mints winnings.
- Optimized UX: one transaction to start a game and one to cash out/forfeit; cell reveals are handled off-chain for responsiveness.

### Deployed Contracts (Somnia Testnet)
- GEM Token: `0x9d6c12B257015849805c0F2935Ee855b398dFF17`
- Somnia Mines: `0xf31a4Da3de241355b8ebE0786651B467eeCfE932`

Network info:
- Chain ID: `50312`
- RPC: `https://dream-rpc.somnia.network/`
- Explorer (example): `https://shannon-explorer.somnia.network/address/0x9d6c12B257015849805c0F2935Ee855b398dFF17`

### Repositories
- GitHub: `https://github.com/crushrrr007/Somnia_Mines` ([repo link](https://github.com/crushrrr007/Somnia_Mines))

### Tokenomics and Rates
- Fixed rate: `0.01 STT = 1000 GEM`
- GEM has 18 decimals. Purchase uses `purchaseTokens()` payable function on the GEM contract.

### Architecture
- `contracts/GEMToken.sol`
  - ERC20 token with `purchaseTokens()` (payable), `mint()` (owner), and `burn()` (internal use).
  - Correct 18-decimal math so quotes and balances are accurate on chain.
- `contracts/SomniaMines.sol`
  - Receives GEM via `transferFrom` on `startGame` (requires prior `approve`).
  - Stores bet in the game contract; on win, mints GEM to player.
  - Multiplier tables per mine count (e.g., 1 and 3 mines included; extensible).
  - Functions:
    - `startGame(uint256 betAmount, uint8 mineCount, uint256 clientSeed)`
    - `revealCell(uint256 gameId, uint8 cellIndex)` [available but not required by the current UX]
    - `cashOut(uint256 gameId)`
    - `cashOutWithClaim(uint256 gameId, uint8 claimedGemsFound)` — allows single-tx settlement using off-chain reveals (for demo UX)
    - `forfeitGame(uint256 gameId)` — single-tx loss settlement
    - Views: `getGame`, `getPlayerStats`

### Frontend (Single HTML)
- File: `mines.html`
- Uses `ethers v6` (CDN) and connects to Somnia Testnet via MetaMask.
- Flow:
  1. Connect wallet and auto-switch to Somnia Testnet.
  2. Purchase GEM with STT via `purchaseTokens()`.
  3. Start game (auto-approve GEM to the game contract if needed).
  4. Reveal cells off-chain instantly for UX (no tx per cell).
  5. Cash out once using `cashOutWithClaim` or forfeit once with `forfeitGame`.
- Balances update live from chain: STT (native) and GEM (ERC20).

### Dev Experience Improvements
- Deployment script (`scripts/deploy.js`) uses EIP-1559 fees and auto gas estimation to avoid network mis-estimations.
- `.gitignore` avoids committing `node_modules`, Hardhat `artifacts/`, `cache/`, logs, and env files.

### How to Run
1. Install deps:
   ```bash
   npm install
   ```
2. Configure `.env` with a funded private key for Somnia Testnet:
   ```bash
   PRIVATE_KEY=0xYOUR_PRIVATE_KEY
   ```
3. Compile and deploy:
   ```bash
   npx hardhat compile
   npx hardhat run scripts/deploy.js --network somnia-testnet
   ```
   The script prints and saves addresses to `deployments/somnia-testnet.json`.
4. Open `mines.html` in a browser with MetaMask installed and connected to Somnia Testnet.

### Security Notes and Tradeoffs
- `cashOutWithClaim` trusts the client-provided progress to settle a game with a single transaction. This is intended for demo UX to avoid a tx per reveal. In production, reveals should be enforced on-chain, or secured with a commit-reveal or ZK approach so the contract can verify progress without trusting the client.
- Randomness uses block properties for seed mixing (sufficient for demo). For production, integrate a verifiable randomness source and commit-reveal patterns.

### Future Work
- Replace off-chain reveals with an on-chain or verifiable reveal mechanism without requiring a tx per cell (e.g., commit-reveal, VRF, batched reveals, or ZK-proof of progress).
- Add more multiplier tables (5, 10 mines are scaffolded in UI) and validate bounds.
- Contract verification on Somnia explorer (if supported by API endpoints).
- Expand frontend to a full app (React/Vite) with history views and analytics.

### Contact
For questions and demo support, please reach out via the GitHub repo issues: `https://github.com/crushrrr007/Somnia_Mines`.


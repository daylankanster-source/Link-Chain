# LinkChain

**On-chain permanent link registry with stake-to-boost ranking, on BOT Chain.**

Every link is pinned to the chain with a unique slug. Anyone can boost a link with BOT — the BOT flows straight to the link owner (minus a 5% platform fee). Boost weight halves every 7 days so the corkboard stays fresh.

Frontend style: **corkboard / sticky-note collage** — cork brown background, colored paper notes, washi tape, pushpin markers, Caveat + Kalam + Patrick Hand handwriting fonts.

## Setup

```bash
npm install
cp .env.example .env      # add your deployer wallet's PRIVATE_KEY
npx hardhat compile
npx hardhat test
```

## Deploy

```bash
npx hardhat run scripts/deploy.js --network botchain_testnet    # testnet first
npx hardhat run scripts/deploy.js --network botchain            # mainnet
```

After deploy, open `frontend/index.html`, set `CONTRACT_ADDRESS` to the deployed address. For mainnet, also switch:
- `chainId` → `"0x2A5"`
- `rpcUrls` → `["https://rpc.botchain.ai"]`
- `blockExplorerUrls` → `["https://scan.botchain.ai"]`
- `chainName` → `"BOT Chain"`

## Contract Functions

- `registerLink(slug, url, title)` payable — pay `registrationFee` (default 0.01 BOT), get link ID
- `boostLink(id)` payable — send BOT; 95% to owner, 5% to platform
- `updateLink(id, newUrl, newTitle)` — owner-only
- `resolveSlug(slug)` view — look up by slug
- `getRecent(limit)` view — most recent links, newest first
- `currentWeight(id)` view — time-decayed boost weight

## Frontend

Single-file `frontend/index.html`. Hosts on Vercel/Netlify. Publish directory: `frontend`.

# Deployment Guide - Somnia Mines

## GitHub Pages Deployment (Recommended - Free)

### Step 1: Enable GitHub Pages
1. Go to your repository: https://github.com/crushrrr007/Somnia_Mines
2. Click on **Settings** tab
3. Scroll down to **Pages** section (left sidebar)
4. Under **Source**, select **GitHub Actions**
5. Click **Save**

### Step 2: Push the Workflow
The GitHub Actions workflow (`.github/workflows/deploy.yml`) will automatically:
- Build your site when you push to `main` branch
- Copy `mines.html` to `index.html` for GitHub Pages
- Deploy to GitHub Pages

### Step 3: Access Your Site
After pushing to main, your site will be available at:
`https://crushrrr007.github.io/Somnia_Mines/`

## Alternative: Netlify (Also Free)

### Step 1: Connect Repository
1. Go to [netlify.com](https://netlify.com)
2. Sign up/Login with GitHub
3. Click **New site from Git**
4. Choose your repository: `crushrrr007/Somnia_Mines`

### Step 2: Configure Build
- **Build command**: Leave empty (not needed for static HTML)
- **Publish directory**: `.` (root directory)
- **Base directory**: Leave empty

### Step 3: Deploy
Click **Deploy site** - Netlify will automatically deploy and give you a URL.

## Manual Deployment (Any Web Server)

Simply upload these files to any web server:
- `mines.html` (rename to `index.html` if needed)
- Any other assets

## Important Notes

- **Network**: Your site connects to Somnia Testnet (Chain ID: 50312)
- **Wallet**: Users need MetaMask or similar wallet extension
- **Tokens**: Users need STT tokens from Somnia Testnet faucet to play
- **Contracts**: Make sure the deployed contract addresses in `mines.html` are current

## Troubleshooting

- **Site not loading**: Check if GitHub Pages is enabled in repository settings
- **Wallet connection issues**: Ensure users are on Somnia Testnet
- **Transaction failures**: Check if users have sufficient STT balance
- **Contract errors**: Verify contract addresses are correct and deployed 
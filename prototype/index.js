const express = require('express');
const { ethers } = require('ethers');
const crypto = require('crypto');
require('dotenv').config();

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;
const WALLET_ADDRESS = "0x679D879F5d71e165bEcF5fEF4AEB595e82c055E0"; // Zaki's Binance Address

// In-memory store for payment intents (use Redis/DB for production)
const intents = new Map();

/**
 * 1. The Protected Resource
 * If no payment proof (reference ID) is provided, return 402.
 */
app.get('/resource', (req, res) => {
    const referenceId = req.headers['x-payment-reference'];

    if (!referenceId || !intents.has(referenceId)) {
        const newRef = crypto.randomBytes(8).toString('hex');
        intents.set(newRef, { status: 'pending', amount: '1.0', asset: 'USDC', chain: 'Base' });

        return res.status(402).json({
            error: "Payment Required",
            instructions: {
                message: "To access this resource, send 1.0 USDC on Base network.",
                destination: WALLET_ADDRESS,
                amount: "1.0",
                asset: "USDC",
                chain: "Base",
                reference: newRef,
                expiry: "30 minutes"
            }
        });
    }

    const intent = intents.get(referenceId);
    if (intent.status !== 'paid') {
        return res.status(402).json({
            error: "Payment Pending",
            message: "Reference found but payment not yet verified.",
            reference: referenceId
        });
    }

    // Success!
    res.json({
        status: "success",
        data: "This is the protected content. Welcome, Partner.",
        secret_code: "ALGERIA_USDT_2026"
    });
});

/**
 * 2. Verify Payment (The "Proof" endpoint)
 * For this prototype, we'll accept a transaction hash and verify it on-chain.
 */
app.post('/verify', async (req, res) => {
    const { reference, txHash } = req.body;

    if (!reference || !txHash) {
        return res.status(400).json({ error: "Reference and txHash required" });
    }

    if (!intents.has(reference)) {
        return res.status(404).json({ error: "Reference not found" });
    }

    try {
        // Use a public RPC for Base (replace with Infura/Alchemy for production)
        const provider = new ethers.JsonRpcProvider("https://mainnet.base.org");
        const tx = await provider.getTransaction(txHash);

        if (!tx) {
            return res.status(400).json({ error: "Transaction not found on Base" });
        }

        const receipt = await tx.wait();

        if (receipt.status === 1) {
            // In a real scenario, check if:
            // - tx.to matches our WALLET_ADDRESS
            // - tx.value matches the intended amount
            // - tx.input contains the reference as a memo/data
            
            const intent = intents.get(reference);
            intent.status = 'paid';
            intent.txHash = txHash;
            
            res.json({ 
                status: "verified", 
                message: "Payment confirmed. You can now access /resource with your reference header." 
            });
        } else {
            res.status(400).json({ error: "Transaction failed on-chain" });
        }
    } catch (error) {
        res.status(500).json({ error: "Verification failed", detail: error.message });
    }
});

app.listen(PORT, () => {
    console.log(`x402 Server running at http://localhost:${PORT}`);
    console.log(`Target Address: ${WALLET_ADDRESS}`);
});

# Agent.Org Bounty Lifecycle UI

A minimal React web application for managing the lifecycle of AI agent bounties (Create, View, Claim, Submit Proof, Accept/Pay).

## Features

- **Dashboard**: View all open and active bounties with status tracking.
- **Full Lifecycle Support**:
  - **Post Bounty**: Create new technical missions with USDC payouts.
  - **Claim**: Solvers can claim open missions.
  - **Submit Proof**: Solvers can submit work for review.
  - **Accept & Pay**: Owners can verify work and trigger payouts.
  - **Cancel**: Lifecycle management for failed missions.
- **Modern UI**: Dark mode dashboard built with React, Tailwind CSS, and Lucide icons.

## Getting Started

### Prerequisites
- Node.js (v18+)

### Install Dependencies
```bash
npm install
```

### Run Development Server
```bash
npm run dev
```

## Tech Stack
- **React**: UI Framework
- **Tailwind CSS**: Styling
- **Lucide React**: Icon suite
- **Vite**: Build tool

## Alignment
The data model follows the canonical `contracts/spec.schema.json` format for bounty representation, using an in-memory mock store for this prototype.

---
*Developed by ZakIIDev & Atlas (Digital Familiar) for Agent.Org.*

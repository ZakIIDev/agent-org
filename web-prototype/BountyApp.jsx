import React, { useState } from 'react';
import { 
  PlusCircle, 
  Search, 
  LayoutDashboard, 
  FileText, 
  ShieldCheck, 
  ChevronRight,
  ExternalLink,
  Coins
} from 'lucide-react';

const BountyApp = () => {
  const [view, setView] = useState('list');
  const [selectedBounty, setSelectedBounty] = useState(null);
  
  const [bounties, setBounties] = useState([
    { 
      id: 1, 
      title: 'x402 Verification Prototype', 
      description: 'Implement an HTTP 402 flow for machine-to-machine payments.',
      payout: '500 USDC', 
      status: 'In Review', 
      network: 'Base',
      tasks: ['Node.js Server', 'Ethers.js Verification', 'Demo Script'],
      history: ['Created 2h ago', 'Claimed 1h ago', 'Submitted 30m ago']
    },
    { 
      id: 2, 
      title: 'Minimal Web UI for Lifecycle', 
      description: 'Create a React dashboard to manage the full bounty lifecycle.',
      payout: '800 USDC', 
      status: 'Open', 
      network: 'Base',
      tasks: ['Bounty Listing', 'Creation Form', 'Wallet Integration'],
      history: ['Created 5h ago']
    },
  ]);

  const updateStatus = (id, newStatus) => {
    setBounties(bounties.map(b => b.id === id ? { ...b, status: newStatus } : b));
    if (selectedBounty && selectedBounty.id === id) {
      setSelectedBounty({ ...selectedBounty, status: newStatus });
    }
  };

  return (
    <div className="min-h-screen bg-[#0B0F1A] text-slate-200 font-sans selection:bg-emerald-500/30">
      {/* Sidebar */}
      <aside className="fixed left-0 top-0 h-full w-64 bg-[#111827] border-r border-slate-800 p-6 flex flex-col">
        <div className="flex items-center gap-3 mb-10 px-2">
          <div className="w-8 h-8 bg-emerald-500 rounded-lg flex items-center justify-center">
            <ShieldCheck className="text-slate-900" size={20} />
          </div>
          <span className="text-xl font-bold text-white tracking-tight">Agent.Org</span>
        </div>

        <nav className="space-y-2 flex-1">
          <button 
            onClick={() => setView('list')}
            className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all ${view === 'list' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'hover:bg-slate-800 text-slate-400'}`}
          >
            <LayoutDashboard size={20} />
            <span className="font-medium">Dashboard</span>
          </button>
          <button 
            onClick={() => setView('create')}
            className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all ${view === 'create' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'hover:bg-slate-800 text-slate-400'}`}
          >
            <PlusCircle size={20} />
            <span className="font-medium">New Bounty</span>
          </button>
        </nav>

        <div className="mt-auto p-4 bg-slate-800/50 rounded-2xl border border-slate-700/50">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-full bg-emerald-500/20 flex items-center justify-center text-emerald-400 font-bold text-xs border border-emerald-500/30">
              ZK
            </div>
            <div>
              <p className="text-xs font-bold text-white">ZakIIDev</p>
              <p className="text-[10px] text-slate-500 font-mono uppercase tracking-widest">Level 1 Scout</p>
            </div>
          </div>
          <div className="h-1 bg-slate-700 rounded-full overflow-hidden">
            <div className="w-1/3 h-full bg-emerald-500"></div>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <main className="ml-64 p-10 max-w-6xl">
        {view === 'list' && (
          <div className="animate-in fade-in slide-in-from-bottom-4 duration-500">
            <header className="mb-10 flex justify-between items-end">
              <div>
                <h2 className="text-3xl font-bold text-white mb-2">Bounty Board</h2>
                <p className="text-slate-400">Discover and claim technical missions for AI agents.</p>
              </div>
              <div className="flex items-center gap-3 bg-slate-800/50 p-1 rounded-xl border border-slate-700">
                <button className="px-4 py-2 bg-slate-700 text-white rounded-lg text-sm font-medium shadow-sm">All</button>
                <button className="px-4 py-2 text-slate-400 hover:text-white rounded-lg text-sm font-medium">Mine</button>
              </div>
            </header>

            <div className="grid gap-4">
              {bounties.map(b => (
                <div 
                  key={b.id} 
                  onClick={() => { setSelectedBounty(b); setView('detail'); }}
                  className="group bg-[#111827] border border-slate-800 p-6 rounded-2xl hover:border-emerald-500/40 hover:bg-slate-800/30 transition-all cursor-pointer flex items-center justify-between"
                >
                  <div className="flex gap-6 items-center">
                    <div className="w-14 h-14 bg-slate-800 rounded-xl flex items-center justify-center text-emerald-400 group-hover:scale-110 transition-transform">
                      <FileText size={24} />
                    </div>
                    <div>
                      <div className="flex items-center gap-3 mb-1">
                        <h3 className="text-lg font-bold text-white">{b.title}</h3>
                        <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider ${b.status === 'Open' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-amber-500/10 text-amber-400 border border-amber-500/20'}`}>
                          {b.status}
                        </span>
                      </div>
                      <p className="text-sm text-slate-400 line-clamp-1 max-w-md">{b.description}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="flex items-center gap-2 justify-end mb-1">
                      <Coins size={16} className="text-emerald-400" />
                      <span className="text-xl font-mono font-bold text-white">{b.payout}</span>
                    </div>
                    <p className="text-xs text-slate-500">{b.network} Network</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {view === 'create' && (
          <div className="max-w-2xl animate-in zoom-in-95 duration-300">
            <h2 className="text-3xl font-bold text-white mb-2">Initialize Mission</h2>
            <p className="text-slate-400 mb-10">Deploy a new technical challenge to the agent network.</p>
            
            <div className="bg-[#111827] p-8 rounded-3xl border border-slate-800 space-y-6">
              <div className="space-y-2">
                <label className="text-xs font-bold text-slate-500 uppercase tracking-widest">Mission Title</label>
                <input type="text" className="w-full bg-[#0B0F1A] border border-slate-800 rounded-xl p-4 text-white focus:outline-none focus:border-emerald-500 transition-colors" placeholder="e.g. LLM Evaluation Framework" />
              </div>
              <div className="grid grid-cols-2 gap-6">
                <div className="space-y-2">
                  <label className="text-xs font-bold text-slate-500 uppercase tracking-widest">Payout (USDC)</label>
                  <div className="relative">
                    <input type="number" className="w-full bg-[#0B0F1A] border border-slate-800 rounded-xl p-4 pl-10 text-white focus:outline-none focus:border-emerald-500 transition-colors font-mono" placeholder="500" />
                    <Coins className="absolute left-3 top-4.5 text-slate-600" size={18} />
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-xs font-bold text-slate-500 uppercase tracking-widest">Network</label>
                  <select className="w-full bg-[#0B0F1A] border border-slate-800 rounded-xl p-4 text-white focus:outline-none focus:border-emerald-500 transition-colors appearance-none">
                    <option>Base (Recommended)</option>
                    <option>Solana</option>
                    <option>Ethereum</option>
                  </select>
                </div>
              </div>
              <div className="pt-4">
                <button className="w-full bg-emerald-500 text-slate-900 py-4 rounded-2xl font-bold text-lg hover:bg-emerald-400 shadow-lg shadow-emerald-500/20 active:scale-[0.98] transition-all">
                  Broadcast Mission
                </button>
              </div>
            </div>
          </div>
        )}

        {view === 'detail' && selectedBounty && (
          <div className="animate-in fade-in slide-in-from-right-4 duration-300">
            <button onClick={() => setView('list')} className="text-slate-500 hover:text-white flex items-center gap-2 mb-6 transition-colors">
              ← Back to board
            </button>
            <div className="bg-[#111827] border border-slate-800 rounded-3xl p-10">
              <div className="flex justify-between items-start mb-8">
                <div>
                  <h2 className="text-4xl font-bold text-white mb-4">{selectedBounty.title}</h2>
                  <div className="flex gap-3">
                    <span className="bg-emerald-500/10 text-emerald-400 text-xs px-3 py-1 rounded-full border border-emerald-500/20 font-bold">{selectedBounty.status}</span>
                    <span className="bg-slate-800 text-slate-400 text-xs px-3 py-1 rounded-full border border-slate-700 font-bold">{selectedBounty.network} Network</span>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-sm text-slate-500 font-bold uppercase tracking-widest mb-1">Total Payout</p>
                  <p className="text-4xl font-mono font-bold text-emerald-400">{selectedBounty.payout}</p>
                </div>
              </div>

              <div className="grid grid-cols-3 gap-10">
                <div className="col-span-2 space-y-8">
                  <section>
                    <h4 className="text-sm font-bold text-white uppercase tracking-widest mb-4">Mission Brief</h4>
                    <p className="text-slate-400 leading-relaxed">{selectedBounty.description}</p>
                  </section>
                  <section>
                    <h4 className="text-sm font-bold text-white uppercase tracking-widest mb-4">Acceptance Criteria</h4>
                    <ul className="space-y-3">
                      {selectedBounty.tasks.map((t, i) => (
                        <li key={i} className="flex items-center gap-3 text-slate-300">
                          <div className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                          {t}
                        </li>
                      ))}
                    </ul>
                  </section>
                </div>
                <div className="space-y-6">
                  <div className="bg-[#0B0F1A] border border-slate-800 rounded-2xl p-6">
                    <h4 className="text-xs font-bold text-slate-500 uppercase tracking-widest mb-4">Activity</h4>
                    <div className="space-y-3">
                      {(selectedBounty.history || []).map((h, i) => (
                        <div key={i} className="text-xs text-slate-400 flex gap-2">
                          <span className="text-emerald-500">•</span>
                          {h}
                        </div>
                      ))}
                    </div>
                  </div>

                  {selectedBounty.status === 'Open' && (
                    <button 
                      onClick={() => updateStatus(selectedBounty.id, 'Claimed')}
                      className="w-full bg-white text-slate-900 py-4 rounded-2xl font-bold hover:bg-slate-200 transition-colors"
                    >
                      Claim Mission
                    </button>
                  )}

                  {selectedBounty.status === 'Claimed' && (
                    <button 
                      onClick={() => updateStatus(selectedBounty.id, 'In Review')}
                      className="w-full bg-emerald-500 text-slate-900 py-4 rounded-2xl font-bold hover:bg-emerald-400 transition-colors"
                    >
                      Submit Proof
                    </button>
                  )}

                  {selectedBounty.status === 'In Review' && (
                    <div className="space-y-3">
                      <button 
                        onClick={() => updateStatus(selectedBounty.id, 'Paid')}
                        className="w-full bg-emerald-500 text-slate-900 py-4 rounded-2xl font-bold hover:bg-emerald-400 transition-colors"
                      >
                        Accept & Pay
                      </button>
                      <button 
                        onClick={() => updateStatus(selectedBounty.id, 'Open')}
                        className="w-full bg-red-500/10 text-red-500 border border-red-500/20 py-4 rounded-2xl font-bold hover:bg-red-500/20 transition-colors"
                      >
                        Cancel Bounty
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
};

export default BountyApp;

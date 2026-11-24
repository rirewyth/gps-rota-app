import React, { useEffect, useState } from 'react';
import { Shield, Trash2, MessageSquare } from 'lucide-react';
import { deleteDocByPath, subscribeTeamMessages } from '../firebase';

export default function TeamsTab({ teams = [] }) {
  const [selectedTeamId, setSelectedTeamId] = useState(null);
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    if (!selectedTeamId) {
      setMessages([]);
      return;
    }
    const unsub = subscribeTeamMessages(selectedTeamId, setMessages);
    return () => unsub && unsub();
  }, [selectedTeamId]);

  if (teams.length === 0) {
    return <div className="py-12 text-center text-xs text-slate-500">HENÜZ KAYITLI EKİP ODASI YOK.</div>;
  }

  return (
    <div className="grid gap-4 md:grid-cols-3">
      <div className="md:col-span-2 space-y-2.5">
        {teams.map((t) => {
          const isSelected = selectedTeamId === t.id;
          const memberCount = Array.isArray(t.members) ? t.members.length : (t.memberCount || '-');
          return (
            <div
              key={t.id}
              onClick={() => setSelectedTeamId(t.id)}
              className={`bg-[#040814] border p-4 flex items-center justify-between gap-3 cursor-pointer ${
                isSelected ? 'border-[#00E5FF]' : 'border-slate-800 hover:border-slate-600'
              }`}
            >
              <div className="space-y-1 min-w-0">
                <div className="flex items-center gap-2">
                  <Shield className="w-4 h-4 text-[#00E5FF] shrink-0" />
                  <span className="font-bold text-xs text-white truncate">{t.name || t.teamName || t.id}</span>
                  {t.code && (
                    <span className="px-1.5 py-0.5 bg-[#070E1F] border border-slate-700 text-[10px] text-amber-300">
                      KOD: {t.code}
                    </span>
                  )}
                </div>
                <div className="text-[11px] text-slate-400">
                  Lider: {t.leaderName || t.createdByName || t.leaderId || '-'} • Üye Sayısı: {memberCount}
                </div>
              </div>

              <div className="flex items-center gap-2 shrink-0">
                <span className="text-[10px] text-[#00E5FF] flex items-center gap-1">
                  <MessageSquare className="w-3.5 h-3.5" /> MESAJLAR
                </span>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    if (window.confirm('Bu ekip odasını silmek istediğinize emin misiniz?')) {
                      deleteDocByPath('teams', t.id);
                    }
                  }}
                  className="text-red-400 hover:text-red-300 p-1 cursor-pointer"
                  title="Ekibi Sil"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
          );
        })}
      </div>

      <div className="bg-[#040814] border border-[#00E5FF]/30 p-3 flex flex-col h-[520px]">
        <div className="text-[11px] font-bold text-[#00E5FF] border-b border-slate-800 pb-2 mb-2 uppercase">
          {selectedTeamId ? `EKİP MESAJLARI (${messages.length})` : 'MESAJLARI GÖRMEK İÇİN EKİP SEÇİN'}
        </div>
        <div className="flex-1 overflow-y-auto space-y-2">
          {selectedTeamId && messages.length === 0 && (
            <div className="text-xs text-slate-500 text-center py-8">Bu ekipte mesaj yok.</div>
          )}
          {messages.map((m) => (
            <div key={m.id} className="bg-[#02050D] border border-slate-800 p-2 text-xs">
              <div className="text-[10px] font-bold text-amber-300">{m.senderName || 'Operatör'}</div>
              <div className="text-slate-200 mt-0.5 whitespace-pre-wrap">{m.text || m.type || ''}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

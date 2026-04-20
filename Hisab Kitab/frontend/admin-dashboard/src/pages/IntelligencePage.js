import React, { useEffect, useState } from 'react';
import { getDepartments, getAnomalies, getLeakage, getReallocate, getHighRisk } from '../api';

export default function IntelligencePage({ user }) {
  const [departments, setDepartments] = useState([]);
  const [selectedDept, setSelectedDept] = useState('');
  const [anomalies, setAnomalies] = useState(null);
  const [leakage, setLeakage] = useState([]);
  const [reallocation, setReallocation] = useState([]);
  const [highRisk, setHighRisk] = useState([]);
  const [tab, setTab] = useState('anomalies');
  const [loading, setLoading] = useState(true);

  const isAdmin = user?.role === 'admin';

  useEffect(() => {
    getDepartments().then(res => {
      const depts = res.departments || [];
      setDepartments(depts);
      if (depts.length) {
        setSelectedDept(depts[0]);
        loadAnomalies(depts[0]);
      }
    }).catch(() => {});

    if (isAdmin) {
      Promise.all([getLeakage(50), getReallocate(), getHighRisk()]).then(([l, r, h]) => {
        setLeakage(l.leakage_indicators || []);
        setReallocation(r.recommendations || []);
        setHighRisk(h.high_risk_projects || []);
        setLoading(false);
      }).catch(() => setLoading(false));
    } else {
      setLoading(false);
    }
  }, [isAdmin]);

  const loadAnomalies = async (dept) => {
    try {
      const data = await getAnomalies(dept);
      setAnomalies(data);
    } catch { setAnomalies(null); }
  };

  const handleDeptChange = (e) => {
    setSelectedDept(e.target.value);
    loadAnomalies(e.target.value);
  };

  const tabs = [
    { id: 'anomalies', label: '🔍 Anomalies', show: true },
    { id: 'leakage', label: '💧 Leakage', show: isAdmin },
    { id: 'reallocation', label: '🔄 Reallocation', show: isAdmin },
    { id: 'highrisk', label: '⚠️ High Risk', show: isAdmin },
  ];

  if (loading) return <div style={s.loading}>Loading intelligence data...</div>;

  return (
    <div>
      <h2 style={s.pageTitle}>🧠 Intelligence Hub</h2>

      {/* Tab bar */}
      <div style={s.tabBar}>
        {tabs.filter(t => t.show).map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            style={{ ...s.tabBtn, ...(tab === t.id ? s.tabActive : {}) }}>
            {t.label}
          </button>
        ))}
      </div>

      {/* Anomalies Tab */}
      {tab === 'anomalies' && (
        <div style={s.section}>
          <div style={s.headerRow}>
            <h3 style={s.sectionTitle}>Anomaly Detection</h3>
            <select value={selectedDept} onChange={handleDeptChange} style={s.select}>
              {departments.map(d => <option key={d} value={d}>{d}</option>)}
            </select>
          </div>
          {anomalies && (
            <>
              <div style={s.statRow}>
                <div style={{ ...s.statBox, borderColor: '#3b82f6' }}>
                  <div style={{ color: '#3b82f6', fontSize: 28, fontWeight: 700 }}>{anomalies.total_records}</div>
                  <div style={s.statLabel}>Total Records</div>
                </div>
                <div style={{ ...s.statBox, borderColor: '#ef4444' }}>
                  <div style={{ color: '#ef4444', fontSize: 28, fontWeight: 700 }}>{anomalies.anomaly_count}</div>
                  <div style={s.statLabel}>Anomalies Found</div>
                </div>
                <div style={{ ...s.statBox, borderColor: '#f59e0b' }}>
                  <div style={{ color: '#f59e0b', fontSize: 28, fontWeight: 700 }}>{anomalies.anomaly_rate}</div>
                  <div style={s.statLabel}>Anomaly Rate</div>
                </div>
              </div>

              {anomalies.anomalies?.length > 0 && (
                <div style={s.tableBox}>
                  <table style={s.table}>
                    <thead>
                      <tr>
                        {['State', 'District', 'Utilization', 'Delay', 'Score'].map(h => (
                          <th key={h} style={s.th}>{h}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {anomalies.anomalies.slice(0, 15).map((a, i) => (
                        <tr key={i} style={{ background: i % 2 ? '#1e293b' : '#0f172a' }}>
                          <td style={s.td}>{a.State}</td>
                          <td style={s.td}>{a.District}</td>
                          <td style={{ ...s.td, color: a.utilization < 50 ? '#ef4444' : '#10b981' }}>{a.utilization?.toFixed(1)}%</td>
                          <td style={s.td}>{a.avg_delay?.toFixed(0)} days</td>
                          <td style={{ ...s.td, color: '#f59e0b' }}>{a.anomaly_score?.toFixed(3)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </>
          )}
        </div>
      )}

      {/* Leakage Tab */}
      {tab === 'leakage' && isAdmin && (
        <div style={s.section}>
          <h3 style={s.sectionTitle}>💧 Leakage Indicators</h3>
          <p style={s.desc}>Districts with high spending but very low utilization — potential fund leakage.</p>
          {leakage.length === 0 ? (
            <p style={s.empty}>No leakage indicators found.</p>
          ) : (
            <div style={s.tableBox}>
              <table style={s.table}>
                <thead>
                  <tr>
                    {['State', 'District', 'Department', 'Allocated', 'Spent', 'Utilization', 'Delay'].map(h => (
                      <th key={h} style={s.th}>{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {leakage.slice(0, 20).map((l, i) => (
                    <tr key={i} style={{ background: i % 2 ? '#1e293b' : '#0f172a' }}>
                      <td style={s.td}>{l.State}</td>
                      <td style={s.td}>{l.District}</td>
                      <td style={s.td}>{l.Department}</td>
                      <td style={s.td}>₹{l.allocated?.toFixed(1)} Cr</td>
                      <td style={s.td}>₹{l.spent?.toFixed(1)} Cr</td>
                      <td style={{ ...s.td, color: '#ef4444', fontWeight: 600 }}>{l.utilization?.toFixed(1)}%</td>
                      <td style={s.td}>{l.avg_delay?.toFixed(0)} days</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Reallocation Tab */}
      {tab === 'reallocation' && isAdmin && (
        <div style={s.section}>
          <h3 style={s.sectionTitle}>🔄 Reallocation Suggestions</h3>
          <p style={s.desc}>AI-driven recommendations to redistribute funds from underspending to overspending districts.</p>
          {reallocation.length === 0 ? (
            <p style={s.empty}>No reallocation suggestions available.</p>
          ) : (
            <div style={s.cardGrid}>
              {reallocation.slice(0, 12).map((r, i) => (
                <div key={i} style={s.reallocCard}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                    <span style={{ fontSize: 20 }}>🔄</span>
                    <span style={{ color: '#f59e0b', fontWeight: 600 }}>{r.Department}</span>
                  </div>
                  <div style={s.flowRow}>
                    <div style={s.fromBox}>
                      <div style={{ fontSize: 11, color: '#94a3b8' }}>FROM</div>
                      <div style={{ color: '#ef4444', fontWeight: 600 }}>{r.from_district}</div>
                      <div style={{ fontSize: 11, color: '#94a3b8' }}>{r.from_state}</div>
                    </div>
                    <div style={{ fontSize: 20, color: '#3b82f6' }}>→</div>
                    <div style={s.toBox}>
                      <div style={{ fontSize: 11, color: '#94a3b8' }}>TO</div>
                      <div style={{ color: '#10b981', fontWeight: 600 }}>{r.to_district}</div>
                      <div style={{ fontSize: 11, color: '#94a3b8' }}>{r.to_state}</div>
                    </div>
                  </div>
                  <div style={{ textAlign: 'center', marginTop: 8, color: '#f59e0b', fontWeight: 700, fontSize: 16 }}>
                    ₹{r.suggested_amount?.toFixed(1)} Cr
                  </div>
                  <div style={{ textAlign: 'center', fontSize: 11, color: '#94a3b8' }}>{r.reason}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* High Risk Tab */}
      {tab === 'highrisk' && isAdmin && (
        <div style={s.section}>
          <h3 style={s.sectionTitle}>⚠️ High-Risk Projects</h3>
          <p style={s.desc}>Projects with critical risk scores based on underspending, delays, and anomaly patterns.</p>
          {highRisk.length === 0 ? (
            <p style={s.empty}>No high-risk projects detected.</p>
          ) : (
            <div style={s.tableBox}>
              <table style={s.table}>
                <thead>
                  <tr>
                    {['State', 'District', 'Department', 'Risk Score', 'Allocated', 'Utilization', 'Delay'].map(h => (
                      <th key={h} style={s.th}>{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {highRisk.slice(0, 20).map((h, i) => (
                    <tr key={i} style={{ background: i % 2 ? '#1e293b' : '#0f172a' }}>
                      <td style={s.td}>{h.State}</td>
                      <td style={s.td}>{h.District}</td>
                      <td style={s.td}>{h.Department}</td>
                      <td style={{ ...s.td, color: h.risk_score > 0.7 ? '#ef4444' : h.risk_score > 0.4 ? '#f59e0b' : '#10b981', fontWeight: 700, fontSize: 16 }}>
                        {h.risk_score?.toFixed(2)}
                      </td>
                      <td style={s.td}>₹{h.allocated?.toFixed(1)} Cr</td>
                      <td style={{ ...s.td, color: h.utilization < 50 ? '#ef4444' : '#10b981' }}>{h.utilization?.toFixed(1)}%</td>
                      <td style={s.td}>{h.avg_delay?.toFixed(0)} days</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

const s = {
  loading: { textAlign: 'center', padding: 60, color: '#94a3b8', fontSize: 18 },
  pageTitle: { color: '#f1f5f9', marginBottom: 20 },
  tabBar: { display: 'flex', gap: 8, marginBottom: 24, flexWrap: 'wrap' },
  tabBtn: {
    padding: '10px 20px', borderRadius: 8, border: '1px solid #334155',
    background: '#1e293b', color: '#94a3b8', cursor: 'pointer', fontSize: 14, fontWeight: 500,
    transition: 'all 0.2s',
  },
  tabActive: { background: '#3b82f6', color: '#fff', borderColor: '#3b82f6' },
  section: { marginBottom: 24 },
  sectionTitle: { color: '#f1f5f9', marginTop: 0, marginBottom: 8 },
  desc: { color: '#94a3b8', fontSize: 13, marginBottom: 16 },
  empty: { color: '#64748b', fontStyle: 'italic' },
  headerRow: { display: 'flex', alignItems: 'center', gap: 16, marginBottom: 16, flexWrap: 'wrap' },
  select: {
    padding: '6px 12px', borderRadius: 8, border: '1px solid #475569',
    background: '#0f172a', color: '#f1f5f9', fontSize: 13,
  },
  statRow: { display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap' },
  statBox: {
    flex: 1, minWidth: 150, background: '#1e293b', borderRadius: 12,
    padding: 20, textAlign: 'center', border: '1px solid #334155', borderLeftWidth: 4,
  },
  statLabel: { color: '#94a3b8', fontSize: 12, marginTop: 4 },
  tableBox: { overflowX: 'auto' },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: 13 },
  th: {
    textAlign: 'left', padding: '8px 12px', color: '#94a3b8',
    borderBottom: '2px solid #334155', fontSize: 12, fontWeight: 600,
  },
  td: { padding: '8px 12px', color: '#e2e8f0', borderBottom: '1px solid #1e293b' },
  cardGrid: {
    display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))',
    gap: 16,
  },
  reallocCard: {
    background: '#1e293b', borderRadius: 12, padding: 16,
    border: '1px solid #334155',
  },
  flowRow: {
    display: 'flex', alignItems: 'center', justifyContent: 'space-around', gap: 12,
  },
  fromBox: { textAlign: 'center', padding: 8, background: '#0f172a', borderRadius: 8, flex: 1 },
  toBox: { textAlign: 'center', padding: 8, background: '#0f172a', borderRadius: 8, flex: 1 },
};

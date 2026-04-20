import React, { useEffect, useState } from 'react';
import { getSummary, getStates, getStateSummary } from '../api';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
  PieChart, Pie, Cell,
} from 'recharts';

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#06b6d4', '#84cc16'];

export default function OverviewPage() {
  const [summary, setSummary] = useState(null);
  const [states, setStates] = useState([]);
  const [selectedState, setSelectedState] = useState('');
  const [stateData, setStateData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([getSummary(), getStates()]).then(([sum, st]) => {
      setSummary(sum);
      setStates(st.states || []);
      if (st.states?.length) {
        setSelectedState(st.states[0]);
        loadStateData(st.states[0]);
      }
      setLoading(false);
    }).catch(() => setLoading(false));
  }, []);

  const loadStateData = async (state) => {
    try {
      const data = await getStateSummary(state);
      setStateData(data || []);
    } catch { setStateData([]); }
  };

  const handleStateChange = (e) => {
    setSelectedState(e.target.value);
    loadStateData(e.target.value);
  };

  if (loading) return <div style={s.loading}>Loading dashboard...</div>;

  const summaryCards = summary ? [
    { label: 'Total Budget', value: `₹${(summary.total_allocated_cr / 100).toFixed(1)}K Cr`, icon: '🏦', color: '#3b82f6' },
    { label: 'Total Spent', value: `₹${(summary.total_spent_cr / 100).toFixed(1)}K Cr`, icon: '📈', color: '#10b981' },
    { label: 'Avg Utilization', value: `${summary.avg_utilization?.toFixed(1)}%`, icon: '📊', color: '#f59e0b' },
    { label: 'Waste', value: `₹${(summary.total_waste_cr / 100).toFixed(1)}K Cr`, icon: '⚠️', color: '#ef4444' },
    { label: 'States', value: summary.total_states, icon: '🗺️', color: '#8b5cf6' },
    { label: 'Districts', value: summary.total_districts, icon: '🏙️', color: '#06b6d4' },
    { label: 'Underspend', value: summary.critical_underspend, icon: '📉', color: '#f97316' },
    { label: 'Overspend', value: summary.critical_overspend, icon: '🔥', color: '#dc2626' },
  ] : [];

  // Aggregate state data by department for charts
  const deptAgg = {};
  stateData.forEach(d => {
    if (!deptAgg[d.Department]) deptAgg[d.Department] = { dept: d.Department, allocated: 0, spent: 0, count: 0, utilSum: 0 };
    deptAgg[d.Department].allocated += d.allocated || 0;
    deptAgg[d.Department].spent += d.spent || 0;
    deptAgg[d.Department].utilSum += d.utilization || 0;
    deptAgg[d.Department].count += 1;
  });
  const chartData = Object.values(deptAgg).map(d => ({
    name: d.dept?.length > 15 ? d.dept.slice(0, 15) + '…' : d.dept,
    Allocated: +(d.allocated).toFixed(1),
    Spent: +(d.spent).toFixed(1),
    Utilization: +(d.utilSum / d.count).toFixed(1),
  }));

  const pieData = summary ? [
    { name: 'Spent', value: summary.total_spent_cr || 0 },
    { name: 'Unspent', value: (summary.total_waste_cr || 0) },
  ] : [];

  return (
    <div>
      <h2 style={s.pageTitle}>📊 Budget Overview</h2>

      {/* Summary Cards */}
      <div style={s.cardGrid}>
        {summaryCards.map((c) => (
          <div key={c.label} style={{ ...s.card, borderLeft: `4px solid ${c.color}` }}>
            <div style={{ fontSize: 24 }}>{c.icon}</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: c.color }}>{c.value}</div>
            <div style={{ color: '#94a3b8', fontSize: 12 }}>{c.label}</div>
          </div>
        ))}
      </div>

      {/* Charts Row */}
      <div style={s.chartRow}>
        {/* Pie chart */}
        <div style={s.chartCard}>
          <h3 style={s.chartTitle}>Budget Utilization</h3>
          <ResponsiveContainer width="100%" height={250}>
            <PieChart>
              <Pie data={pieData} cx="50%" cy="50%" outerRadius={90} dataKey="value" label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}>
                {pieData.map((_, i) => <Cell key={i} fill={COLORS[i]} />)}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* State selector + bar chart */}
        <div style={{ ...s.chartCard, flex: 2 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
            <h3 style={{ ...s.chartTitle, margin: 0 }}>State Breakdown</h3>
            <select value={selectedState} onChange={handleStateChange} style={s.select}>
              {states.map(st => <option key={st} value={st}>{st}</option>)}
            </select>
          </div>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
              <XAxis dataKey="name" tick={{ fill: '#94a3b8', fontSize: 10 }} angle={-20} textAnchor="end" height={60} />
              <YAxis tick={{ fill: '#94a3b8', fontSize: 11 }} />
              <Tooltip contentStyle={{ background: '#1e293b', border: '1px solid #475569', borderRadius: 8 }} />
              <Legend />
              <Bar dataKey="Allocated" fill="#3b82f6" radius={[4, 4, 0, 0]} />
              <Bar dataKey="Spent" fill="#10b981" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* District table */}
      {stateData.length > 0 && (
        <div style={s.tableCard}>
          <h3 style={s.chartTitle}>District Details — {selectedState}</h3>
          <div style={{ overflowX: 'auto' }}>
            <table style={s.table}>
              <thead>
                <tr>
                  {['District', 'Department', 'Allocated (Cr)', 'Spent (Cr)', 'Utilization %', 'Avg Delay (days)'].map(h => (
                    <th key={h} style={s.th}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {stateData.slice(0, 20).map((d, i) => (
                  <tr key={i} style={{ background: i % 2 ? '#1e293b' : '#0f172a' }}>
                    <td style={s.td}>{d.District}</td>
                    <td style={s.td}>{d.Department}</td>
                    <td style={s.td}>{d.allocated?.toFixed(1)}</td>
                    <td style={s.td}>{d.spent?.toFixed(1)}</td>
                    <td style={{ ...s.td, color: d.utilization < 50 ? '#ef4444' : d.utilization > 120 ? '#f59e0b' : '#10b981' }}>
                      {d.utilization?.toFixed(1)}%
                    </td>
                    <td style={{ ...s.td, color: d.avg_delay > 90 ? '#ef4444' : '#94a3b8' }}>
                      {d.avg_delay?.toFixed(0)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {stateData.length > 20 && <p style={{ color: '#94a3b8', fontSize: 12 }}>Showing 20 of {stateData.length} records</p>}
        </div>
      )}
    </div>
  );
}

const s = {
  loading: { textAlign: 'center', padding: 60, color: '#94a3b8', fontSize: 18 },
  pageTitle: { color: '#f1f5f9', marginBottom: 20 },
  cardGrid: {
    display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))',
    gap: 12, marginBottom: 24,
  },
  card: {
    background: '#1e293b', borderRadius: 12, padding: 16,
    textAlign: 'center', border: '1px solid #334155',
  },
  chartRow: { display: 'flex', gap: 16, marginBottom: 24, flexWrap: 'wrap' },
  chartCard: {
    flex: 1, minWidth: 300, background: '#1e293b', borderRadius: 12,
    padding: 20, border: '1px solid #334155',
  },
  chartTitle: { color: '#f1f5f9', marginTop: 0, fontSize: 16 },
  select: {
    padding: '6px 12px', borderRadius: 8, border: '1px solid #475569',
    background: '#0f172a', color: '#f1f5f9', fontSize: 13,
  },
  tableCard: {
    background: '#1e293b', borderRadius: 12, padding: 20, border: '1px solid #334155',
  },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: 13 },
  th: {
    textAlign: 'left', padding: '8px 12px', color: '#94a3b8',
    borderBottom: '2px solid #334155', fontSize: 12, fontWeight: 600,
  },
  td: { padding: '8px 12px', color: '#e2e8f0', borderBottom: '1px solid #1e293b' },
};

import { useState, useEffect, useMemo } from 'react'
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
  PieChart, Pie, Cell,
  AreaChart, Area,
  ReferenceLine,
} from 'recharts'
import { fetchApi } from '../api/client'
import Header from '../components/layout/Header'
import { classifyBP } from '../utils/bpCategory'
import styles from './Charts.module.css'

const PIE_COLORS = ['#4caf50', '#fdd835', '#ff9800', '#f44336', '#b71c1c']
const PIE_LABELS = ['Normal', 'Elevated', 'Stage 1', 'Stage 2', 'Crisis']

function aggregateByPeriod(entries, period, dateKey, valueKeys) {
  if (!entries.length) return []

  const buckets = {}

  entries.forEach((entry) => {
    const d = new Date(entry[dateKey])
    if (isNaN(d)) return
    let key
    if (period === 'Daily') {
      key = d.toISOString().split('T')[0]
    } else if (period === 'Weekly') {
      // ISO week: start of week (Monday)
      const day = d.getDay()
      const diff = d.getDate() - day + (day === 0 ? -6 : 1)
      const monday = new Date(d)
      monday.setDate(diff)
      key = monday.toISOString().split('T')[0]
    } else {
      // Monthly
      key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
    }

    if (!buckets[key]) {
      buckets[key] = { _count: 0 }
      valueKeys.forEach((k) => (buckets[key][k] = 0))
    }
    buckets[key]._count++
    valueKeys.forEach((k) => {
      buckets[key][k] += entry[k] || 0
    })
  })

  const sorted = Object.entries(buckets).sort(([a], [b]) => a.localeCompare(b))

  const limitMap = { Daily: 30, Weekly: 12, Monthly: 12 }
  const sliced = sorted.slice(-(limitMap[period] || 30))

  return sliced.map(([key, vals]) => {
    const result = {}
    if (period === 'Monthly') {
      const [y, m] = key.split('-')
      result.date = new Date(y, m - 1).toLocaleDateString('en-US', { month: 'short', year: '2-digit' })
    } else {
      result.date = new Date(key).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
    }
    valueKeys.forEach((k) => {
      result[k] = Math.round(vals[k] / vals._count)
    })
    return result
  })
}

function aggregateUserGrowth(users, period) {
  if (!users.length) return []

  const sorted = [...users].sort((a, b) => new Date(a.created_at) - new Date(b.created_at))
  let cumulative = 0

  if (period === 'Daily') {
    const buckets = {}
    sorted.forEach((u) => {
      const d = new Date(u.created_at).toISOString().split('T')[0]
      cumulative++
      buckets[d] = cumulative
    })
    return Object.entries(buckets)
      .sort(([a], [b]) => a.localeCompare(b))
      .slice(-30)
      .map(([key, val]) => ({
        label: new Date(key).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
        users: val,
      }))
  }

  if (period === 'Weekly') {
    const weekMs = 7 * 24 * 60 * 60 * 1000
    const firstDate = new Date(sorted[0].created_at)
    const now = new Date()
    const data = []
    let weekStart = new Date(firstDate)
    let weekNum = 1
    let idx = 0

    while (weekStart < now && weekNum <= 52) {
      const weekEnd = new Date(weekStart.getTime() + weekMs)
      while (idx < sorted.length && new Date(sorted[idx].created_at) < weekEnd) {
        cumulative++
        idx++
      }
      data.push({ label: `W${weekNum}`, users: cumulative })
      weekStart = weekEnd
      weekNum++
    }
    return data.slice(-12)
  }

  // Monthly
  const buckets = {}
  sorted.forEach((u) => {
    const d = new Date(u.created_at)
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
    cumulative++
    buckets[key] = cumulative
  })
  return Object.entries(buckets)
    .sort(([a], [b]) => a.localeCompare(b))
    .slice(-12)
    .map(([key, val]) => {
      const [y, m] = key.split('-')
      return {
        label: new Date(y, m - 1).toLocaleDateString('en-US', { month: 'short', year: '2-digit' }),
        users: val,
      }
    })
}

export default function Charts() {
  const [rawReadings, setRawReadings] = useState([])
  const [rawUsers, setRawUsers] = useState([])
  const [pieData, setPieData] = useState([])
  const [trendPeriod, setTrendPeriod] = useState('Daily')
  const [growthPeriod, setGrowthPeriod] = useState('Weekly')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function load() {
      try {
        const [readingsRes, usersRes] = await Promise.all([
          fetchApi('/admin/readings?limit=200&offset=0'),
          fetchApi('/admin/users?limit=200&offset=0'),
        ])

        const readings = readingsRes.readings || readingsRes || []
        const users = usersRes.users || usersRes || []

        setRawReadings(readings)
        setRawUsers(users)

        // Build pie chart data
        const cats = { Normal: 0, Elevated: 0, 'Stage 1': 0, 'Stage 2': 0, Crisis: 0 }
        readings.forEach((r) => {
          const cat = classifyBP(r.systolic, r.diastolic)
          cats[cat.label] = (cats[cat.label] || 0) + 1
        })
        const total = readings.length
        setPieData(
          PIE_LABELS.map((label, i) => ({
            name: label,
            value: cats[label] || 0,
            pct: total > 0 ? Math.round(((cats[label] || 0) / total) * 100) : 0,
            color: PIE_COLORS[i],
          }))
        )
      } catch {
        // endpoints may not be available
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  // Aggregate BP trends based on period selection
  const bpTrends = useMemo(() => {
    const prepared = rawReadings.map((r) => ({
      date: r.reading_date || r.created_at,
      avgSystolic: r.systolic,
      avgDiastolic: r.diastolic,
    }))
    return aggregateByPeriod(prepared, trendPeriod, 'date', ['avgSystolic', 'avgDiastolic'])
  }, [rawReadings, trendPeriod])

  // Aggregate user growth based on period selection
  const userGrowth = useMemo(() => {
    return aggregateUserGrowth(rawUsers, growthPeriod)
  }, [rawUsers, growthPeriod])

  const totalReadings = pieData.reduce((s, d) => s + d.value, 0)

  if (loading) return <><Header title="Charts & Analytics" /><div className={styles.loading}>Loading...</div></>

  return (
    <>
      <Header title="Charts & Analytics" />
      <div className={styles.chartsGrid}>

        {/* BP Trends */}
        <div className={`${styles.chartCard} ${styles.fullWidth}`}>
          <div className={styles.chartHeader}>
            <span className={styles.chartTitle}>Blood Pressure Trends</span>
            <div className={styles.chartControls}>
              {['Daily', 'Weekly', 'Monthly'].map((p) => (
                <button
                  key={p}
                  className={`${styles.periodBtn} ${trendPeriod === p ? styles.periodActive : ''}`}
                  onClick={() => setTrendPeriod(p)}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>
          <div className={styles.chartSubtitle}>
            Average systolic and diastolic readings — {trendPeriod.toLowerCase()} view
          </div>
          <div className={styles.chartBody}>
            <ResponsiveContainer width="100%" height={250}>
              <LineChart data={bpTrends}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="date" tick={{ fontSize: 11, fill: '#999' }} />
                <YAxis domain={[60, 180]} tick={{ fontSize: 11, fill: '#999' }} />
                <Tooltip />
                <ReferenceLine y={140} stroke="#f44336" strokeDasharray="6 4" strokeOpacity={0.3} label="" />
                <ReferenceLine y={90} stroke="#2196f3" strokeDasharray="6 4" strokeOpacity={0.3} label="" />
                <Line type="monotone" dataKey="avgSystolic" stroke="#f44336" strokeWidth={2.5} dot={false} name="Avg Systolic" />
                <Line type="monotone" dataKey="avgDiastolic" stroke="#2196f3" strokeWidth={2.5} dot={false} name="Avg Diastolic" />
                <Legend />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* BP Category Distribution */}
        <div className={styles.chartCard}>
          <div className={styles.chartHeader}>
            <span className={styles.chartTitle}>BP Category Distribution</span>
          </div>
          <div className={styles.chartSubtitle}>All readings ({totalReadings} total)</div>
          <div className={styles.pieContainer}>
            <ResponsiveContainer width={180} height={180}>
              <PieChart>
                <Pie
                  data={pieData}
                  cx="50%"
                  cy="50%"
                  innerRadius={40}
                  outerRadius={70}
                  dataKey="value"
                  stroke="none"
                >
                  {pieData.map((entry, i) => (
                    <Cell key={i} fill={entry.color} />
                  ))}
                </Pie>
              </PieChart>
            </ResponsiveContainer>
            <div className={styles.pieLabels}>
              {pieData.map((d) => (
                <div key={d.name} className={styles.pieLabel}>
                  <div className={styles.pieDot} style={{ background: d.color }} />
                  <span>{d.name}</span>
                  <span className={styles.pieValue}>{d.value}</span>
                  <span className={styles.piePct}>{d.pct}%</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* User Growth */}
        <div className={styles.chartCard}>
          <div className={styles.chartHeader}>
            <span className={styles.chartTitle}>User Growth</span>
            <div className={styles.chartControls}>
              {['Daily', 'Weekly', 'Monthly'].map((p) => (
                <button
                  key={p}
                  className={`${styles.periodBtn} ${growthPeriod === p ? styles.periodActive : ''}`}
                  onClick={() => setGrowthPeriod(p)}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>
          <div className={styles.chartSubtitle}>Cumulative user registrations — {growthPeriod.toLowerCase()} view</div>
          <div className={styles.chartBody}>
            <ResponsiveContainer width="100%" height={220}>
              <AreaChart data={userGrowth}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="label" tick={{ fontSize: 11, fill: '#999' }} />
                <YAxis tick={{ fontSize: 11, fill: '#999' }} />
                <Tooltip />
                <Area type="monotone" dataKey="users" stroke="#1976d2" strokeWidth={2.5} fill="#1976d2" fillOpacity={0.12} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

      </div>
    </>
  )
}

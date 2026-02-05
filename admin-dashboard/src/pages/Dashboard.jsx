import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts'
import { fetchApi } from '../api/client'
import Header from '../components/layout/Header'
import StatCard from '../components/shared/StatCard'
import Badge from '../components/shared/Badge'
import { classifyBP } from '../utils/bpCategory'
import styles from './Dashboard.module.css'

export default function Dashboard() {
  const [stats, setStats] = useState(null)
  const [recentActivity, setRecentActivity] = useState([])
  const [weeklyData, setWeeklyData] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function load() {
      try {
        const [statsData, usersData, readingsData] = await Promise.all([
          fetchApi('/admin/stats'),
          fetchApi('/admin/users?limit=5&offset=0'),
          fetchApi('/admin/readings?limit=10&offset=0'),
        ])

        setStats(statsData)

        // Build recent activity from users and readings
        const users = (usersData.users || usersData || [])
        const readings = (readingsData.readings || readingsData || [])

        const activity = [
          ...users.map((u) => ({
            type: u.is_approved ? 'approval' : 'new_user',
            detail: `${u.name || 'User #' + u.id} registered`,
            time: u.created_at,
          })),
          ...readings.map((r) => {
            const cat = classifyBP(r.systolic, r.diastolic)
            return {
              type: cat.css === 'crisis' ? 'alert' : 'reading',
              detail: `${r.user_name || 'User #' + r.user_id} — ${r.systolic}/${r.diastolic} mmHg`,
              time: r.reading_date || r.created_at,
            }
          }),
        ]
          .sort((a, b) => new Date(b.time) - new Date(a.time))
          .slice(0, 7)

        setRecentActivity(activity)

        // Build weekly chart data from readings
        const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        const dayCounts = {}
        days.forEach((d) => (dayCounts[d] = 0))
        readings.forEach((r) => {
          const d = new Date(r.reading_date || r.created_at)
          dayCounts[days[d.getDay()]] = (dayCounts[days[d.getDay()]] || 0) + 1
        })
        setWeeklyData(
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => ({
            day: d,
            count: dayCounts[d] || 0,
          }))
        )
      } catch {
        // stats endpoint might not exist yet, use empty data
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  const badgeProps = {
    new_user: { color: 'blue', label: 'New User' },
    reading: { color: 'green', label: 'Reading' },
    approval: { color: 'orange', label: 'Approval' },
    alert: { color: 'red', label: 'Alert' },
  }

  function timeAgo(iso) {
    if (!iso) return ''
    const diff = Date.now() - new Date(iso).getTime()
    const mins = Math.floor(diff / 60000)
    if (mins < 1) return 'Just now'
    if (mins < 60) return `${mins} min ago`
    const hrs = Math.floor(mins / 60)
    if (hrs < 24) return `${hrs} hr ago`
    return `${Math.floor(hrs / 24)} days ago`
  }

  if (loading) return <><Header title="Dashboard" /><div className={styles.loading}>Loading...</div></>

  return (
    <>
      <Header title="Dashboard" />
      <div className={styles.statsGrid}>
        <Link to="/users" className={styles.statLink}>
          <StatCard
            icon={<svg viewBox="0 0 24 24" fill="#1976d2"><path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5z" /></svg>}
            iconBg="#e3f2fd"
            label="Total Users"
            value={stats?.total_users ?? '—'}
          />
        </Link>
        <Link to="/users?status=pending" className={styles.statLink}>
          <StatCard
            icon={<svg viewBox="0 0 24 24" fill="#ef6c00"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" /></svg>}
            iconBg="#fff3e0"
            label="Pending Approvals"
            value={stats?.pending_approvals ?? '—'}
          />
        </Link>
        <Link to="/charts" className={styles.statLink}>
          <StatCard
            icon={<svg viewBox="0 0 24 24" fill="#2e7d32"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" /></svg>}
            iconBg="#e8f5e9"
            label="Total Readings"
            value={stats?.total_readings?.toLocaleString() ?? '—'}
          />
        </Link>
        <Link to="/readings" className={styles.statLink}>
          <StatCard
            icon={<svg viewBox="0 0 24 24" fill="#7b1fa2"><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z" /></svg>}
            iconBg="#f3e5f5"
            label="Readings Today"
            value={stats?.readings_today ?? '—'}
          />
        </Link>
      </div>

      <div className={styles.twoCol}>
        <div className={styles.card}>
          <div className={styles.cardHeader}>
            <span className={styles.cardTitle}>Recent Activity</span>
            <Link to="/readings" className={styles.cardAction}>View all</Link>
          </div>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Event</th>
                <th>Details</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {recentActivity.map((a, i) => (
                <tr key={i}>
                  <td>
                    <Badge color={badgeProps[a.type]?.color}>{badgeProps[a.type]?.label}</Badge>
                  </td>
                  <td>{a.detail}</td>
                  <td className={styles.timeAgo}>{timeAgo(a.time)}</td>
                </tr>
              ))}
              {recentActivity.length === 0 && (
                <tr><td colSpan={3} style={{ textAlign: 'center', color: '#999' }}>No recent activity</td></tr>
              )}
            </tbody>
          </table>
        </div>

        <div className={styles.card}>
          <div className={styles.cardHeader}>
            <span className={styles.cardTitle}>Readings This Week</span>
            <Link to="/charts" className={styles.cardAction}>View charts</Link>
          </div>
          <div className={styles.chartWrap}>
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={weeklyData}>
                <XAxis dataKey="day" tick={{ fontSize: 11, fill: '#999' }} axisLine={false} tickLine={false} />
                <YAxis hide />
                <Tooltip />
                <Bar dataKey="count" fill="#1976d2" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </>
  )
}

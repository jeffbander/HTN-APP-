import { useState, useEffect, useCallback } from 'react'
import { fetchApi } from '../../api/client'
import Header from '../../components/layout/Header'
import TabBar from '../../components/shared/TabBar'
import Badge from '../../components/shared/Badge'
import styles from './CuffRequests.module.css'

const STATUS_BADGE = {
  pending: 'orange',
  approved: 'blue',
  shipped: 'green',
  delivered: 'green',
  cancelled: 'red',
}

export default function CuffRequests() {
  const [requests, setRequests] = useState([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState('pending')

  const load = useCallback(async () => {
    try {
      const data = await fetchApi('/shipping/cuff-requests')
      setRequests(data)
    } catch {
      // ignore
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const markShipped = async (id) => {
    try {
      await fetchApi(`/shipping/cuff-requests/${id}/ship`, {
        method: 'PUT',
        body: JSON.stringify({}),
      })
      load()
    } catch {
      // ignore
    }
  }

  const markDelivered = async (id) => {
    try {
      await fetchApi(`/shipping/cuff-requests/${id}/deliver`, { method: 'PUT' })
      load()
    } catch {
      // ignore
    }
  }

  const filtered = requests.filter((r) => {
    if (tab === 'pending') return r.status === 'pending' || r.status === 'approved'
    if (tab === 'shipped') return r.status === 'shipped'
    return r.status === 'delivered' || r.status === 'cancelled'
  })

  const pendingCount = requests.filter((r) => r.status === 'pending' || r.status === 'approved').length
  const shippedCount = requests.filter((r) => r.status === 'shipped').length
  const completedCount = requests.filter((r) => r.status === 'delivered' || r.status === 'cancelled').length

  const tabs = [
    { key: 'pending', label: 'Pending', count: pendingCount },
    { key: 'shipped', label: 'Shipped', count: shippedCount },
    { key: 'completed', label: 'Completed', count: completedCount },
  ]

  if (loading) return <><Header title="Cuff Requests" /><div className={styles.loading}>Loading...</div></>

  return (
    <>
      <Header title="Cuff Requests" />
      <TabBar tabs={tabs} active={tab} onChange={setTab} />
      <div className={styles.table}>
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>User</th>
              <th>Status</th>
              <th>Requested</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((r) => (
              <tr key={r.id}>
                <td>#{r.id}</td>
                <td>{r.user_name || `User #${r.user_id}`}</td>
                <td>
                  <Badge color={STATUS_BADGE[r.status] || 'gray'}>
                    {r.status}
                  </Badge>
                </td>
                <td className={styles.date}>
                  {r.created_at ? new Date(r.created_at).toLocaleDateString() : '—'}
                </td>
                <td>
                  {(r.status === 'pending' || r.status === 'approved') && (
                    <button className={styles.shipBtn} onClick={() => markShipped(r.id)}>
                      Mark Shipped
                    </button>
                  )}
                  {r.status === 'shipped' && (
                    <button className={styles.deliverBtn} onClick={() => markDelivered(r.id)}>
                      Mark Delivered
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td colSpan={5} className={styles.empty}>No requests in this category.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  )
}

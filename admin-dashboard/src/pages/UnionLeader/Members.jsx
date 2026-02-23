import { useState, useEffect, useCallback } from 'react'
import { fetchApi } from '../../api/client'
import Header from '../../components/layout/Header'
import TabBar from '../../components/shared/TabBar'
import Badge from '../../components/shared/Badge'
import styles from './Members.module.css'

export default function Members() {
  const [members, setMembers] = useState([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState('active')

  const load = useCallback(async () => {
    try {
      const data = await fetchApi('/union-leader/members')
      setMembers(data.members || [])
    } catch {
      // ignore
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const approve = async (userId) => {
    try {
      await fetchApi(`/union-leader/members/${userId}/approve`, { method: 'PUT' })
      load()
    } catch {
      // ignore
    }
  }

  const active = members.filter((m) => m.is_active && m.user_status !== 'deactivated')
  const inactive = members.filter((m) => !m.is_active || m.user_status === 'deactivated')
  const pending = members.filter((m) => m.user_status === 'pending_approval')
  const displayed = tab === 'active' ? active : inactive

  const tabs = [
    { key: 'active', label: 'Active', count: active.length },
    { key: 'inactive', label: 'Inactive', count: inactive.length },
  ]

  if (loading) return <><Header title="Members" /><div className={styles.loading}>Loading...</div></>

  return (
    <>
      <Header title="Members" />
      {pending.length > 0 && (
        <div className={styles.pendingBanner}>
          <strong>{pending.length}</strong> member{pending.length !== 1 ? 's' : ''} pending approval
        </div>
      )}
      <TabBar tabs={tabs} active={tab} onChange={setTab} />
      <div className={styles.grid}>
        {displayed.map((m) => (
          <div key={m.id} className={styles.card}>
            <div className={styles.cardHeader}>
              <span className={styles.name}>{m.name || `User #${m.id}`}</span>
              <Badge color={
                m.user_status === 'active' ? 'green' :
                m.user_status === 'pending_approval' ? 'orange' :
                m.user_status === 'deactivated' ? 'red' : 'gray'
              }>
                {(m.user_status || 'unknown').replace(/_/g, ' ')}
              </Badge>
            </div>
            <div className={styles.cardBody}>
              {m.email && <div className={styles.detail}>{m.email}</div>}
              {m.phone && <div className={styles.detail}>{m.phone}</div>}
            </div>
            {m.user_status === 'pending_approval' && (
              <div className={styles.cardActions}>
                <button className={styles.approveBtn} onClick={() => approve(m.id)}>
                  Approve
                </button>
              </div>
            )}
          </div>
        ))}
        {displayed.length === 0 && (
          <div className={styles.empty}>
            No {tab} members found.
          </div>
        )}
      </div>
    </>
  )
}

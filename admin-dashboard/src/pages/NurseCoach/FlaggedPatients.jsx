import { useState, useEffect, useCallback } from 'react'
import { Link } from 'react-router-dom'
import { fetchApi } from '../../api/client'
import Header from '../../components/layout/Header'
import Badge from '../../components/shared/Badge'
import styles from './Patients.module.css'

export default function FlaggedPatients() {
  const [patients, setPatients] = useState([])
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    try {
      const data = await fetchApi('/nurse/flagged-patients')
      setPatients(data)
    } catch {
      // ignore
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  if (loading) return <><Header title="Flagged Patients" /><div className={styles.loading}>Loading...</div></>

  return (
    <>
      <Header title="Flagged Patients" />
      <div className={styles.grid}>
        {patients.map((p) => (
          <Link key={p.id} to={`/patients/${p.id}`} className={styles.card}>
            <div className={styles.cardTop}>
              <span className={styles.name}>{p.name || `User #${p.id}`}</span>
              <Badge color="red">Flagged</Badge>
            </div>
            <div className={styles.detail}>{p.email}</div>
            <div className={styles.detail}>
              Status: <Badge color={p.user_status === 'active' ? 'green' : 'gray'}>
                {(p.user_status || 'unknown').replace(/_/g, ' ')}
              </Badge>
            </div>
          </Link>
        ))}
        {patients.length === 0 && (
          <div className={styles.empty}>No flagged patients.</div>
        )}
      </div>
    </>
  )
}

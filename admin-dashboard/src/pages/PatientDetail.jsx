import { useState, useEffect } from 'react'
import { useParams, Link } from 'react-router-dom'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend, ReferenceLine } from 'recharts'
import { fetchApi } from '../api/client'
import Header from '../components/layout/Header'
import BpCategoryBadge from '../components/shared/BpCategoryBadge'
import Badge from '../components/shared/Badge'
import Pagination from '../components/shared/Pagination'
import Modal from '../components/shared/Modal'
import { classifyBP } from '../utils/bpCategory'
import styles from './PatientDetail.module.css'

const USER_STATUS_OPTIONS = [
  { value: 'pending_approval', label: 'Pending Approval' },
  { value: 'pending_registration', label: 'Pending Registration' },
  { value: 'pending_cuff', label: 'Pending Cuff' },
  { value: 'pending_first_reading', label: 'Pending First Reading' },
  { value: 'active', label: 'Active' },
  { value: 'deactivated', label: 'Deactivated' },
  { value: 'enrollment_only', label: 'Enrollment Only' },
]

const STATUS_COLORS = {
  pending_approval: 'orange',
  pending_registration: 'orange',
  pending_cuff: 'orange',
  pending_first_reading: 'blue',
  active: 'green',
  deactivated: 'red',
  enrollment_only: 'gray',
}

const OUTCOME_COLORS = {
  completed: { bg: '#e8f5e9', color: '#2e7d32' },
  left_vm: { bg: '#fff3e0', color: '#e65100' },
  no_answer: { bg: '#fafafa', color: '#666' },
  email_sent: { bg: '#e3f2fd', color: '#1565c0' },
  requested_callback: { bg: '#f3e5f5', color: '#7b1fa2' },
  refused: { bg: '#ffebee', color: '#c62828' },
  sent_materials: { bg: '#e0f7fa', color: '#00695c' },
}

export default function PatientDetail() {
  const { id } = useParams()
  const [user, setUser] = useState(null)
  const [readings, setReadings] = useState([])
  const [chartReadings, setChartReadings] = useState([])
  const [notes, setNotes] = useState([])
  const [callHistory, setCallHistory] = useState([])
  const [readingOffset, setReadingOffset] = useState(0)
  const [totalReadings, setTotalReadings] = useState(0)
  const [noteText, setNoteText] = useState('')
  const [loading, setLoading] = useState(true)
  const [flagModal, setFlagModal] = useState(false)
  const [expandedAttempts, setExpandedAttempts] = useState({})
  const readingLimit = 8

  async function loadData() {
    setLoading(true)
    try {
      const [userData, readingsData, chartData] = await Promise.all([
        fetchApi(`/admin/users/${id}`),
        fetchApi(`/admin/readings?user_id=${id}&limit=${readingLimit}&offset=${readingOffset}`),
        fetchApi(`/admin/readings?user_id=${id}&limit=200&offset=0`),
      ])

      setUser(userData.user || userData)
      const rList = readingsData.readings || readingsData || []
      setReadings(rList)
      setTotalReadings(readingsData.total_count ?? rList.length)

      // Full chart data (up to 200 readings)
      const cList = chartData.readings || chartData || []
      setChartReadings(cList)

      // Load notes
      try {
        const notesData = await fetchApi(`/admin/users/${id}/notes`)
        setNotes(notesData.notes || notesData || [])
      } catch {
        setNotes([])
      }

      // Load call history
      try {
        const callData = await fetchApi(`/admin/users/${id}/call-history`)
        setCallHistory(callData.attempts || [])
      } catch {
        setCallHistory([])
      }
    } catch {
      // fail gracefully
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadData()
  }, [id, readingOffset])

  async function handleAddNote() {
    if (!noteText.trim()) return
    try {
      await fetchApi(`/admin/users/${id}/notes`, {
        method: 'POST',
        body: JSON.stringify({ text: noteText }),
      })
      setNoteText('')
      // Reload notes
      const notesData = await fetchApi(`/admin/users/${id}/notes`)
      setNotes(notesData.notes || notesData || [])
    } catch (err) {
      alert(err.message)
    }
  }

  async function handleToggleFlag() {
    try {
      await fetchApi(`/admin/users/${id}/flag`, { method: 'PUT' })
      setFlagModal(false)
      // Reload user
      const userData = await fetchApi(`/admin/users/${id}`)
      setUser(userData.user || userData)
    } catch (err) {
      alert(err.message)
    }
  }

  async function handleDeactivate() {
    if (!confirm('Are you sure you want to deactivate this user?')) return
    try {
      await fetchApi(`/admin/users/${id}/deactivate`, { method: 'PUT' })
      const userData = await fetchApi(`/admin/users/${id}`)
      setUser(userData.user || userData)
    } catch (err) {
      alert(err.message)
    }
  }

  async function handleStatusChange(newStatus) {
    if (newStatus === user.user_status) return
    try {
      await fetchApi(`/admin/users/${id}/status`, {
        method: 'PUT',
        body: JSON.stringify({ user_status: newStatus }),
      })
      const userData = await fetchApi(`/admin/users/${id}`)
      setUser(userData.user || userData)
    } catch (err) {
      alert(err.message)
    }
  }

  function formatDate(iso) {
    if (!iso) return '\u2014'
    return new Date(iso).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })
  }

  function formatDateTime(iso) {
    if (!iso) return '\u2014'
    return new Date(iso).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    })
  }

  if (loading) return <><Header title="Patient Detail" backLink="/users" backLabel="Back to Users" /><div className={styles.loading}>Loading...</div></>
  if (!user) return <><Header title="Patient Detail" backLink="/users" backLabel="Back to Users" /><div className={styles.loading}>User not found</div></>

  const latest = readings[0]
  const latestCat = latest ? classifyBP(latest.systolic, latest.diastolic) : null

  // Build chart data from ALL readings (sorted ascending)
  const chartData = [...chartReadings]
    .sort((a, b) => new Date(a.reading_date) - new Date(b.reading_date))
    .map((r) => ({
      date: formatDateTime(r.reading_date),
      systolic: r.systolic,
      diastolic: r.diastolic,
      heartRate: r.heart_rate,
    }))

  const getInitials = (name) => {
    if (!name) return '??'
    return name.split(' ').map((w) => w[0]).join('').toUpperCase().slice(0, 2)
  }

  // Use server-provided averages if available, fall back to local computation
  const avg30Sys = user.avg_30_day?.systolic ?? (readings.length > 0 ? Math.round(readings.reduce((s, r) => s + r.systolic, 0) / readings.length) : null)
  const avg30Dia = user.avg_30_day?.diastolic ?? (readings.length > 0 ? Math.round(readings.reduce((s, r) => s + r.diastolic, 0) / readings.length) : null)

  return (
    <>
      <Header title="Patient Detail" backLink="/users" backLabel="Back to Users" />

      {/* Patient Header */}
      <div className={styles.patientHeader}>
        <div className={styles.patientInfo}>
          <div className={styles.patientAvatar}>{getInitials(user.name)}</div>
          <div>
            <div className={styles.nameRow}>
              <div className={styles.patientName}>{user.name || `User #${user.id}`}</div>
              {user.is_flagged && (
                <div className={styles.flagIndicator}>{'\u26A0'} Flagged for follow-up</div>
              )}
            </div>
            <div className={styles.badges}>
              <Badge color={STATUS_COLORS[user.user_status] || 'gray'}>
                {USER_STATUS_OPTIONS.find(o => o.value === user.user_status)?.label || user.user_status}
              </Badge>
              <select
                className={styles.statusSelect}
                value={user.user_status || ''}
                onChange={(e) => handleStatusChange(e.target.value)}
              >
                {USER_STATUS_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>{o.label}</option>
                ))}
              </select>
            </div>
            <div className={styles.patientMeta}>
              <div className={styles.metaItem}>Email: <span>{user.email || '\u2014'}</span></div>
              {user.dob && <div className={styles.metaItem}>DOB: <span>{user.dob}</span></div>}
              <div className={styles.metaItem}>Union: <span>{user.union_name || `#${user.union_id || '\u2014'}`}</span></div>
              {user.gender && <div className={styles.metaItem}>Gender: <span>{user.gender}</span></div>}
              {user.rank && <div className={styles.metaItem}>Rank: <span>{user.rank}</span></div>}
              {user.work_status && <div className={styles.metaItem}>Status: <span>{user.work_status}</span></div>}
              <div className={styles.metaItem}>Member since: <span>{formatDate(user.created_at)}</span></div>
            </div>
          </div>
        </div>
        <div className={styles.patientActions}>
          <button className={styles.btnFlag} onClick={() => setFlagModal(true)}>
            {'\u26A0'} {user.is_flagged ? 'Remove Flag' : 'Flag User'}
          </button>
          {user.is_active && (
            <button className={styles.btnDeactivate} onClick={handleDeactivate}>Deactivate</button>
          )}
        </div>
      </div>

      {/* Health & Demographic Info */}
      <div className={styles.healthSection}>
        <div className={styles.card}>
          <div className={styles.cardHeader}>
            <span className={styles.cardTitle}>Demographics</span>
          </div>
          <div className={styles.infoGrid}>
            <div className={styles.infoItem}><span className={styles.infoLabel}>Gender</span><span className={styles.infoValue}>{user.gender || '\u2014'}</span></div>
            <div className={styles.infoItem}><span className={styles.infoLabel}>Race</span><span className={styles.infoValue}>{user.race || '\u2014'}</span></div>
            <div className={styles.infoItem}><span className={styles.infoLabel}>Ethnicity</span><span className={styles.infoValue}>{user.ethnicity || '\u2014'}</span></div>
            <div className={styles.infoItem}><span className={styles.infoLabel}>Date of Birth</span><span className={styles.infoValue}>{user.dob || '\u2014'}</span></div>
            <div className={styles.infoItem}><span className={styles.infoLabel}>Phone</span><span className={styles.infoValue}>{user.phone || '\u2014'}</span></div>
            <div className={styles.infoItem}><span className={styles.infoLabel}>Address</span><span className={styles.infoValue}>{user.address || '\u2014'}</span></div>
            <div className={styles.infoItem}><span className={styles.infoLabel}>Rank</span><span className={styles.infoValue}>{user.rank || '\u2014'}</span></div>
            <div className={styles.infoItem}><span className={styles.infoLabel}>Work Status</span><span className={styles.infoValue}>{user.work_status || '\u2014'}</span></div>
          </div>
        </div>
        <div className={styles.card}>
          <div className={styles.cardHeader}>
            <span className={styles.cardTitle}>Health Information</span>
          </div>
          <div className={styles.infoGrid}>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>Height</span>
              <span className={styles.infoValue}>{user.height_inches ? `${Math.floor(user.height_inches / 12)}' ${user.height_inches % 12}"` : '\u2014'}</span>
            </div>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>Weight</span>
              <span className={styles.infoValue}>{user.weight_lbs ? `${user.weight_lbs} lbs` : '\u2014'}</span>
            </div>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>High Blood Pressure</span>
              <span className={styles.infoValue}>{user.has_high_blood_pressure != null ? (user.has_high_blood_pressure ? 'Yes' : 'No') : '\u2014'}</span>
            </div>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>On BP Medication</span>
              <span className={styles.infoValue}>{user.on_bp_medication != null ? (user.on_bp_medication ? 'Yes' : 'No') : '\u2014'}</span>
            </div>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>Missed Doses</span>
              <span className={styles.infoValue}>{user.missed_doses != null ? user.missed_doses : '\u2014'}</span>
            </div>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>Smoking Status</span>
              <span className={styles.infoValue}>{user.smoking_status || '\u2014'}</span>
            </div>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>Medications</span>
              <span className={styles.infoValue}>{user.medications || '\u2014'}</span>
            </div>
            <div className={styles.infoItem}>
              <span className={styles.infoLabel}>Chronic Conditions</span>
              <span className={styles.infoValue}>
                {user.chronic_conditions
                  ? (() => { try { const c = Array.isArray(user.chronic_conditions) ? user.chronic_conditions : JSON.parse(user.chronic_conditions); return c.length ? c.join(', ') : 'None'; } catch { return user.chronic_conditions; } })()
                  : '\u2014'}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Quick Stats */}
      <div className={styles.patientStats}>
        <div className={styles.miniStat}>
          <div className={styles.miniStatLabel}>Latest Reading</div>
          {latest ? (
            <>
              <div className={styles.bpValue}>
                <span className={styles.miniStatValue} style={{ color: latestCat?.color }}>
                  {latest.systolic}
                </span>
                <span className={styles.bpSlash}>/</span>
                <span className={styles.miniStatValue} style={{ color: latestCat?.color }}>
                  {latest.diastolic}
                </span>
              </div>
              <div className={styles.miniStatSub}>
                {formatDateTime(latest.reading_date)} &middot; <BpCategoryBadge systolic={latest.systolic} diastolic={latest.diastolic} />
              </div>
            </>
          ) : (
            <div className={styles.miniStatValue} style={{ color: '#999' }}>{'\u2014'}</div>
          )}
        </div>
        <div className={styles.miniStat}>
          <div className={styles.miniStatLabel}>30-Day Average</div>
          {avg30Sys ? (
            <div className={styles.bpValue}>
              <span className={styles.miniStatValue} style={{ color: classifyBP(avg30Sys, avg30Dia).color }}>
                {avg30Sys}
              </span>
              <span className={styles.bpSlash}>/</span>
              <span className={styles.miniStatValue} style={{ color: classifyBP(avg30Sys, avg30Dia).color }}>
                {avg30Dia}
              </span>
            </div>
          ) : (
            <div className={styles.miniStatValue} style={{ color: '#999' }}>{'\u2014'}</div>
          )}
          <div className={styles.miniStatSub}>Based on {user.total_readings || chartReadings.length} readings</div>
        </div>
        <div className={styles.miniStat}>
          <div className={styles.miniStatLabel}>Total Readings</div>
          <div className={styles.miniStatValue} style={{ color: '#1976d2' }}>{totalReadings}</div>
          <div className={styles.miniStatSub}>Since {formatDate(user.created_at)}</div>
        </div>
        <div className={styles.miniStat}>
          <div className={styles.miniStatLabel}>Heart Rate (Latest)</div>
          {latest?.heart_rate ? (
            <>
              <div className={styles.miniStatValue} style={{ color: '#4caf50' }}>{latest.heart_rate}</div>
              <div className={styles.miniStatSub}>bpm</div>
            </>
          ) : (
            <div className={styles.miniStatValue} style={{ color: '#999' }}>{'\u2014'}</div>
          )}
        </div>
      </div>

      {/* BP Chart — uses full chart history */}
      {chartData.length > 0 && (
        <div className={styles.card} style={{ marginBottom: 24 }}>
          <div className={styles.cardHeader}>
            <span className={styles.cardTitle}>Blood Pressure History ({chartReadings.length} readings)</span>
          </div>
          <div className={styles.cardBody}>
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="date" tick={{ fontSize: 10, fill: '#999' }} />
                <YAxis domain={[60, 180]} tick={{ fontSize: 10, fill: '#999' }} />
                <Tooltip />
                <ReferenceLine y={140} stroke="#f44336" strokeDasharray="4 4" strokeOpacity={0.2} />
                <ReferenceLine y={130} stroke="#ff9800" strokeDasharray="4 4" strokeOpacity={0.2} />
                <Line type="monotone" dataKey="systolic" stroke="#f44336" strokeWidth={2} name="Systolic" />
                <Line type="monotone" dataKey="diastolic" stroke="#2196f3" strokeWidth={2} name="Diastolic" />
                <Line type="monotone" dataKey="heartRate" stroke="#4caf50" strokeWidth={1.5} strokeDasharray="4 3" name="Heart Rate" />
                <Legend />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* Two Column: Readings + Notes */}
      <div className={styles.twoCol}>
        <div className={styles.card}>
          <div className={styles.cardHeader}>
            <span className={styles.cardTitle}>Reading History</span>
          </div>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Date</th>
                <th>Systolic</th>
                <th>Diastolic</th>
                <th>HR</th>
                <th>Category</th>
              </tr>
            </thead>
            <tbody>
              {readings.map((r) => {
                const cat = classifyBP(r.systolic, r.diastolic)
                return (
                  <tr key={r.id}>
                    <td>{formatDateTime(r.reading_date)}</td>
                    <td style={{ color: cat.color, fontWeight: 600 }}>{r.systolic}</td>
                    <td style={{ color: cat.color, fontWeight: 600 }}>{r.diastolic}</td>
                    <td>{r.heart_rate || '\u2014'}</td>
                    <td><BpCategoryBadge systolic={r.systolic} diastolic={r.diastolic} /></td>
                  </tr>
                )
              })}
              {readings.length === 0 && (
                <tr><td colSpan={5} style={{ textAlign: 'center', color: '#999', padding: 24 }}>No readings</td></tr>
              )}
            </tbody>
          </table>
          <Pagination offset={readingOffset} limit={readingLimit} total={totalReadings} onChange={setReadingOffset} />
        </div>

        <div className={styles.card}>
          <div className={styles.cardHeader}>
            <span className={styles.cardTitle}>Admin Notes</span>
            <span style={{ fontSize: 12, color: '#999' }}>{notes.length} notes</span>
          </div>
          <div className={styles.noteForm}>
            <textarea
              className={styles.noteInput}
              placeholder="Add a note about this patient..."
              value={noteText}
              onChange={(e) => setNoteText(e.target.value)}
            />
            <button className={styles.noteSubmit} onClick={handleAddNote}>Add Note</button>
          </div>
          {notes.map((note, i) => (
            <div key={note.id || i} className={styles.note}>
              <div className={styles.noteHeader}>
                <span className={styles.noteAuthor}>{note.admin_name || 'Admin'}</span>
                <span className={styles.noteDate}>
                  {note.created_at ? new Date(note.created_at).toLocaleString('en-US', {
                    month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit',
                  }) : ''}
                </span>
              </div>
              <div className={styles.noteText}>{note.text}</div>
            </div>
          ))}
          {notes.length === 0 && (
            <div style={{ padding: 24, textAlign: 'center', color: '#999', fontSize: 14 }}>No notes yet</div>
          )}
        </div>
      </div>

      {/* Contact History */}
      {callHistory.length > 0 && (
        <div className={styles.card} style={{ marginBottom: 24 }}>
          <div className={styles.cardHeader}>
            <span className={styles.cardTitle}>Contact History</span>
            <span style={{ fontSize: 12, color: '#999' }}>{callHistory.length} attempts</span>
          </div>
          <div className={styles.contactTimeline}>
            {callHistory.map((attempt) => {
              const oc = OUTCOME_COLORS[attempt.outcome] || { bg: '#f5f5f5', color: '#666' }
              const isExpanded = expandedAttempts[attempt.id]
              return (
                <div key={attempt.id} className={styles.contactItem}>
                  <div className={styles.contactItemHeader}>
                    <div className={styles.contactItemLeft}>
                      <span
                        className={styles.outcomeBadge}
                        style={{ background: oc.bg, color: oc.color }}
                      >
                        {attempt.outcome?.replace(/_/g, ' ')}
                      </span>
                      <span className={styles.contactCaller}>by {attempt.admin_name || 'Admin'}</span>
                      <span className={styles.contactDate}>
                        {attempt.created_at ? new Date(attempt.created_at).toLocaleString('en-US', {
                          month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit',
                        }) : ''}
                      </span>
                    </div>
                    <div className={styles.contactItemRight}>
                      {attempt.follow_up_date && (
                        <span className={styles.contactFollowUp}>Follow-up: {formatDate(attempt.follow_up_date)}</span>
                      )}
                      {attempt.materials_sent && <span className={styles.contactIndicator}>Materials</span>}
                      {attempt.referral_made && <span className={styles.contactIndicator}>Referral: {attempt.referral_to}</span>}
                    </div>
                  </div>
                  {attempt.notes && (
                    <div className={styles.contactNotes}>
                      {attempt.notes.length > 200 && !isExpanded ? (
                        <>
                          {attempt.notes.slice(0, 200)}...
                          <button
                            className={styles.expandBtn}
                            onClick={() => setExpandedAttempts((prev) => ({ ...prev, [attempt.id]: true }))}
                          >
                            Show more
                          </button>
                        </>
                      ) : (
                        attempt.notes
                      )}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Flag confirmation modal */}
      <Modal
        open={flagModal}
        title={user.is_flagged ? 'Remove Flag' : 'Flag User'}
        confirmLabel={user.is_flagged ? 'Remove Flag' : 'Flag User'}
        confirmColor={user.is_flagged ? '#4caf50' : '#ff9800'}
        onCancel={() => setFlagModal(false)}
        onConfirm={handleToggleFlag}
      >
        <p>
          {user.is_flagged
            ? <>Are you sure you want to remove the flag from <strong>{user.name}</strong>?</>
            : <>Are you sure you want to flag <strong>{user.name}</strong> for follow-up? This will highlight them in the system for clinical review.</>
          }
        </p>
      </Modal>
    </>
  )
}

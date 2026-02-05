import { useState, useEffect, useCallback } from 'react'
import { Link } from 'react-router-dom'
import { fetchApi } from '../api/client'
import Header from '../components/layout/Header'
import SidePanel from '../components/shared/SidePanel'
import { classifyBP } from '../utils/bpCategory'
import styles from './CallList.module.css'

const TABS = [
  { key: 'nurse', label: 'Nurse' },
  { key: 'coach', label: 'HTN Coach' },
  { key: 'no_reading', label: 'No-Reading' },
]

const OUTCOMES = [
  { value: 'completed', label: 'Completed — Spoke with patient' },
  { value: 'left_vm', label: 'Left Voicemail' },
  { value: 'no_answer', label: 'No Answer' },
  { value: 'email_sent', label: 'Email Sent' },
  { value: 'requested_callback', label: 'Requested Callback' },
  { value: 'refused', label: 'Refused' },
  { value: 'sent_materials', label: 'Sent Materials' },
]

const CLOSE_REASONS = [
  { value: 'resolved', label: 'Resolved' },
  { value: 'not_needed', label: 'Not needed upon clinical review' },
  { value: 'other', label: 'Other' },
]

function getInitials(name) {
  if (!name) return '??'
  return name.split(' ').map((w) => w[0]).join('').toUpperCase().slice(0, 2)
}

function formatDate(iso) {
  if (!iso) return '\u2014'
  return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

function formatDateTime(iso) {
  if (!iso) return '\u2014'
  return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
}

export default function CallList() {
  const [activeTab, setActiveTab] = useState('nurse')
  const [items, setItems] = useState([])
  const [summary, setSummary] = useState({ nurse: 0, coach: 0, no_reading: 0 })
  const [statusFilter, setStatusFilter] = useState('open')
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)

  // Modal states
  const [callModal, setCallModal] = useState(null) // item being logged
  const [emailModal, setEmailModal] = useState(null) // item for email compose
  const [scheduleModal, setScheduleModal] = useState(null) // item for scheduling
  const [resolveModal, setResolveModal] = useState(null) // item to close
  const [autoCloseMsg, setAutoCloseMsg] = useState(null)

  // Call logging form
  const [callOutcome, setCallOutcome] = useState('')
  const [callNotes, setCallNotes] = useState('')
  const [followUpNeeded, setFollowUpNeeded] = useState(false)
  const [followUpDate, setFollowUpDate] = useState('')
  const [materialsSent, setMaterialsSent] = useState(false)
  const [materialsDesc, setMaterialsDesc] = useState('')
  const [referralMade, setReferralMade] = useState(false)
  const [referralTo, setReferralTo] = useState('')

  // Email compose form
  const [emailTo, setEmailTo] = useState('')
  const [emailSubject, setEmailSubject] = useState('')
  const [emailBody, setEmailBody] = useState('')
  const [emailTemplates, setEmailTemplates] = useState([])

  // Schedule form
  const [scheduleDate, setScheduleDate] = useState('')

  // Resolve form
  const [resolveReason, setResolveReason] = useState('resolved')
  const [resolveNote, setResolveNote] = useState('')

  const [saving, setSaving] = useState(false)

  const loadItems = useCallback(async () => {
    try {
      const data = await fetchApi(`/admin/call-list?list_type=${activeTab}&status=${statusFilter}`)
      setItems(data.items || [])
      setSummary(data.summary || { nurse: 0, coach: 0, no_reading: 0 })
    } catch {
      // fail gracefully
    } finally {
      setLoading(false)
    }
  }, [activeTab, statusFilter])

  useEffect(() => {
    setLoading(true)
    loadItems()
  }, [loadItems])

  async function handleRefresh() {
    setRefreshing(true)
    try {
      await fetchApi('/admin/call-list/refresh', { method: 'POST' })
      await loadItems()
    } catch (err) {
      alert(err.message)
    } finally {
      setRefreshing(false)
    }
  }

  // ---------- Call Logging ----------
  function openCallModal(item) {
    setCallModal(item)
    setCallOutcome('')
    setCallNotes('')
    setFollowUpNeeded(false)
    setFollowUpDate('')
    setMaterialsSent(false)
    setMaterialsDesc('')
    setReferralMade(false)
    setReferralTo('')
    setAutoCloseMsg(null)
  }

  async function submitCall() {
    if (!callOutcome) return
    setSaving(true)
    try {
      const body = {
        outcome: callOutcome,
        notes: callNotes,
        follow_up_needed: followUpNeeded,
        materials_sent: materialsSent,
        materials_desc: materialsDesc,
        referral_made: referralMade,
        referral_to: referralTo,
      }
      if (followUpDate) body.follow_up_date = followUpDate

      const result = await fetchApi(`/admin/call-list/${callModal.id}/attempt`, {
        method: 'POST',
        body: JSON.stringify(body),
      })

      if (result.auto_closed) {
        setAutoCloseMsg('This item has been auto-closed after 3 unsuccessful attempts. The patient will be excluded from the call list for 2 weeks.')
      } else {
        setCallModal(null)
      }
      await loadItems()
    } catch (err) {
      alert(err.message)
    } finally {
      setSaving(false)
    }
  }

  // ---------- Email Compose ----------
  async function openEmailModal(item) {
    setEmailModal(item)
    setEmailTo(item.user?.email || '')
    setEmailSubject('')
    setEmailBody('')
    try {
      const data = await fetchApi(`/admin/email-templates?list_type=${activeTab}`)
      setEmailTemplates(data.templates || [])
    } catch {
      setEmailTemplates([])
    }
  }

  function selectTemplate(templateId) {
    const tpl = emailTemplates.find((t) => t.id === Number(templateId))
    if (!tpl) return
    const patientName = emailModal?.user?.name || 'Patient'
    setEmailSubject(tpl.subject.replace(/\{\{patient_name\}\}/g, patientName))
    setEmailBody(tpl.body.replace(/\{\{patient_name\}\}/g, patientName))
  }

  async function submitEmail() {
    if (!emailTo || !emailSubject || !emailBody) return
    setSaving(true)
    try {
      await fetchApi(`/admin/call-list/${emailModal.id}/send-email`, {
        method: 'POST',
        body: JSON.stringify({ to: emailTo, subject: emailSubject, body: emailBody }),
      })
      setEmailModal(null)
      await loadItems()
    } catch (err) {
      alert(err.message)
    } finally {
      setSaving(false)
    }
  }

  // ---------- Schedule Follow-Up ----------
  function openScheduleModal(item) {
    setScheduleModal(item)
    setScheduleDate('')
  }

  async function submitSchedule(days) {
    setSaving(true)
    try {
      const body = days != null ? { follow_up_days: days } : { follow_up_date: scheduleDate }
      await fetchApi(`/admin/call-list/${scheduleModal.id}/schedule`, {
        method: 'PUT',
        body: JSON.stringify(body),
      })
      setScheduleModal(null)
      await loadItems()
    } catch (err) {
      alert(err.message)
    } finally {
      setSaving(false)
    }
  }

  // ---------- Resolve / Close ----------
  function openResolveModal(item) {
    setResolveModal(item)
    setResolveReason('resolved')
    setResolveNote('')
  }

  async function submitResolve() {
    setSaving(true)
    try {
      await fetchApi(`/admin/call-list/${resolveModal.id}/close`, {
        method: 'PUT',
        body: JSON.stringify({ reason: resolveReason, note: resolveNote }),
      })
      setResolveModal(null)
      await loadItems()
    } catch (err) {
      alert(err.message)
    } finally {
      setSaving(false)
    }
  }

  // ---------- Helpers ----------
  const bpColor = (systolic, diastolic) => classifyBP(systolic, diastolic).color

  const openCount = items.filter((i) => i.status === 'open').length
  const overdueCount = items.filter((i) => i.follow_up_date && new Date(i.follow_up_date) < new Date()).length

  const priorityStyles = {
    high: { badge: styles.priorityHigh, reason: styles.reasonHigh, avatar: { background: '#ffebee', color: '#c62828' } },
    medium: { badge: styles.priorityMedium, reason: styles.reasonMedium, avatar: { background: '#fff3e0', color: '#e65100' } },
    low: { badge: styles.priorityLow, reason: styles.reasonLow, avatar: { background: '#fff8e1', color: '#f57f17' } },
  }

  if (loading) return <><Header title="Call List" /><div className={styles.loading}>Loading...</div></>

  return (
    <>
      <Header title="Call List" />

      {/* Tab Navigation */}
      <div className={styles.tabBar}>
        {TABS.map((tab) => (
          <button
            key={tab.key}
            className={`${styles.tab} ${activeTab === tab.key ? styles.tabActive : ''}`}
            onClick={() => setActiveTab(tab.key)}
          >
            {tab.label}
            <span className={styles.tabBadge}>{summary[tab.key] || 0}</span>
          </button>
        ))}
      </div>

      {/* Summary Cards */}
      <div className={styles.summaryRow}>
        <div className={styles.summaryCard}>
          <div className={styles.summaryIcon} style={{ background: '#e3f2fd' }}>
            <svg viewBox="0 0 24 24" width="24" height="24" fill="#1976d2"><path d="M20 15.5c-1.25 0-2.45-.2-3.57-.57a1.02 1.02 0 00-1.02.24l-2.2 2.2a15.045 15.045 0 01-6.59-6.59l2.2-2.21a.96.96 0 00.25-1A11.36 11.36 0 018.5 4c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1 0 9.39 7.61 17 17 17 .55 0 1-.45 1-1v-3.5c0-.55-.45-1-1-1z" /></svg>
          </div>
          <div>
            <div className={styles.summaryLabel}>Open Items</div>
            <div className={styles.summaryValue} style={{ color: '#1976d2' }}>{items.length}</div>
          </div>
        </div>
        <div className={styles.summaryCard}>
          <div className={styles.summaryIcon} style={{ background: overdueCount > 0 ? '#ffebee' : '#e8f5e9' }}>
            <svg viewBox="0 0 24 24" width="24" height="24" fill={overdueCount > 0 ? '#c62828' : '#2e7d32'}><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z" /></svg>
          </div>
          <div>
            <div className={styles.summaryLabel}>Overdue Follow-ups</div>
            <div className={styles.summaryValue} style={{ color: overdueCount > 0 ? '#c62828' : '#2e7d32' }}>{overdueCount}</div>
          </div>
        </div>
        <div className={styles.summaryCard}>
          <div className={styles.summaryIcon} style={{ background: '#e8f5e9' }}>
            <svg viewBox="0 0 24 24" width="24" height="24" fill="#2e7d32"><path d="M9 16.2L4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4L9 16.2z" /></svg>
          </div>
          <div>
            <div className={styles.summaryLabel}>Total Across Lists</div>
            <div className={styles.summaryValue} style={{ color: '#2e7d32' }}>{summary.nurse + summary.coach + summary.no_reading}</div>
          </div>
        </div>
      </div>

      {/* Toolbar */}
      <div className={styles.toolbar}>
        <div className={styles.filterGroup}>
          <span className={styles.filterLabel}>Status:</span>
          <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className={styles.select}>
            <option value="open">Open</option>
            <option value="closed">Closed</option>
            <option value="all">All</option>
          </select>
        </div>
        <button className={styles.refreshBtn} onClick={handleRefresh} disabled={refreshing}>
          {refreshing ? 'Refreshing...' : 'Refresh List'}
        </button>
        <span className={styles.resultCount}>{items.length} items</span>
      </div>

      {/* Cards */}
      {items.map((item) => {
        const user = item.user || {}
        const ps = priorityStyles[item.priority] || priorityStyles.medium
        const latest = item.latest_reading
        const avg7 = item.avg_7_day
        const avg30 = item.avg_30_day
        const isOverdue = item.follow_up_date && new Date(item.follow_up_date) < new Date()

        return (
          <div key={item.id} className={styles.callCard}>
            <div className={styles.callCardHeader}>
              <div className={styles.callCardLeft}>
                <div className={styles.callAvatar} style={ps.avatar}>
                  {getInitials(user.name)}
                </div>
                <div>
                  <div className={styles.callName}>{user.name || `User #${user.id}`}</div>
                  <div className={styles.callMeta}>
                    {user.union_name || '\u2014'} &middot; Member since {formatDate(user.created_at)} &middot; {item.reading_count || 0} readings
                  </div>
                  {user.phone && (
                    <div className={styles.phoneNumber}>
                      <svg viewBox="0 0 24 24" fill="currentColor"><path d="M20 15.5c-1.25 0-2.45-.2-3.57-.57a1.02 1.02 0 00-1.02.24l-2.2 2.2a15.045 15.045 0 01-6.59-6.59l2.2-2.21a.96.96 0 00.25-1A11.36 11.36 0 018.5 4c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1 0 9.39 7.61 17 17 17 .55 0 1-.45 1-1v-3.5c0-.55-.45-1-1-1z" /></svg>
                      {user.phone}
                    </div>
                  )}
                  {user.email && (
                    <div className={styles.emailDisplay}>{user.email}</div>
                  )}
                </div>
              </div>
              <div className={styles.headerRight}>
                <span className={`${styles.priorityBadge} ${ps.badge}`}>
                  {item.priority === 'high' ? '\u26A0 HIGH' : item.priority === 'medium' ? '\u26A0 MEDIUM' : 'LOW'}
                </span>
                <div className={styles.attemptCount}>
                  <strong>{item.attempt_count || 0}</strong> of 3 attempts
                  {item.last_attempt && (
                    <span> &middot; Last: {formatDate(item.last_attempt.created_at)}</span>
                  )}
                </div>
              </div>
            </div>

            {/* Reason Box */}
            <div className={styles.callReason}>
              <div className={`${styles.reasonBox} ${ps.reason}`}>
                <div className={styles.reasonTitle}>{item.priority_title}</div>
                <div className={styles.reasonDetail}>{item.priority_detail}</div>
              </div>
            </div>

            {/* Readings Row */}
            <div className={styles.callReadings}>
              {latest && (
                <div className={styles.readingSnapshot}>
                  <span className={styles.readingLabel}>Latest</span>
                  <span className={styles.readingValue} style={{ color: bpColor(latest.systolic, latest.diastolic) }}>
                    {latest.systolic}/{latest.diastolic}
                  </span>
                </div>
              )}
              {avg7 && (
                <div className={styles.readingSnapshot}>
                  <span className={styles.readingLabel}>7-Day Avg</span>
                  <span className={styles.readingValue} style={{ color: bpColor(avg7.systolic, avg7.diastolic) }}>
                    {avg7.systolic}/{avg7.diastolic}
                  </span>
                </div>
              )}
              {avg30 && (
                <div className={styles.readingSnapshot}>
                  <span className={styles.readingLabel}>30-Day Avg</span>
                  <span className={styles.readingValue} style={{ color: bpColor(avg30.systolic, avg30.diastolic) }}>
                    {avg30.systolic}/{avg30.diastolic}
                  </span>
                </div>
              )}
              {latest?.heart_rate && (
                <div className={styles.readingSnapshot}>
                  <span className={styles.readingLabel}>Heart Rate</span>
                  <span className={styles.readingValue} style={{ color: '#666' }}>
                    {latest.heart_rate} bpm
                  </span>
                </div>
              )}
            </div>

            {/* Follow-up & Last Note */}
            {(item.follow_up_date || item.last_note) && (
              <div className={styles.cardFooterInfo}>
                {item.follow_up_date && (
                  <div className={`${styles.followUpDate} ${isOverdue ? styles.overdueHighlight : ''}`}>
                    Follow-up: {formatDate(item.follow_up_date)}
                    {isOverdue && ' (OVERDUE)'}
                  </div>
                )}
                {item.last_note && (
                  <div className={styles.lastNote}>
                    <div className={styles.notePreviewLabel}>Last Note ({item.last_note.admin_name}, {formatDate(item.last_note.date)})</div>
                    <div className={styles.notePreviewText}>{item.last_note.text}</div>
                  </div>
                )}
              </div>
            )}

            {/* Action Buttons */}
            {item.status === 'open' && (
              <div className={styles.callActions}>
                <button className={`${styles.actionBtn} ${styles.btnLogCall}`} onClick={() => openCallModal(item)}>
                  Log Call
                </button>
                <button className={`${styles.actionBtn} ${styles.btnSendEmail}`} onClick={() => openEmailModal(item)}>
                  Send Email
                </button>
                <button className={`${styles.actionBtn} ${styles.btnSchedule}`} onClick={() => openScheduleModal(item)}>
                  Schedule Follow-up
                </button>
                <button className={`${styles.actionBtn} ${styles.btnResolve}`} onClick={() => openResolveModal(item)}>
                  Resolve
                </button>
                <Link to={`/users/${user.id}`} className={`${styles.actionBtn} ${styles.btnView}`}>
                  View Patient
                </Link>
              </div>
            )}
            {item.status === 'closed' && (
              <div className={styles.callActions}>
                <span style={{ fontSize: 13, color: '#888' }}>
                  Closed: {item.close_reason?.replace(/_/g, ' ')} {item.closed_at && `on ${formatDate(item.closed_at)}`}
                </span>
                <Link to={`/users/${user.id}`} className={`${styles.actionBtn} ${styles.btnView}`} style={{ marginLeft: 'auto' }}>
                  View Patient
                </Link>
              </div>
            )}
          </div>
        )
      })}

      {items.length === 0 && (
        <div className={styles.empty}>No patients on this list. Click "Refresh List" to evaluate all patients.</div>
      )}

      {/* ---------- Call Logging Side Panel ---------- */}
      <SidePanel
        open={!!callModal}
        title={`Log Call — ${callModal?.user?.name || ''}`}
        onClose={() => { setCallModal(null); setAutoCloseMsg(null) }}
      >
        {autoCloseMsg && (
          <div className={styles.autoCloseAlert}>{autoCloseMsg}</div>
        )}
        {!autoCloseMsg && (
          <>
            <div className={styles.formGroup}>
              <label className={styles.formLabel}>Outcome</label>
              <select className={styles.formSelect} value={callOutcome} onChange={(e) => setCallOutcome(e.target.value)}>
                <option value="">Select outcome...</option>
                {OUTCOMES.map((o) => (
                  <option key={o.value} value={o.value}>{o.label}</option>
                ))}
              </select>
            </div>

            <div className={styles.formGroup}>
              <label className={styles.formLabel}>Notes</label>
              <textarea
                className={styles.formTextarea}
                value={callNotes}
                onChange={(e) => setCallNotes(e.target.value)}
                placeholder="Notes about the call..."
              />
            </div>

            {callOutcome === 'completed' && (
              <>
                <div className={styles.formCheckbox}>
                  <input type="checkbox" id="followUp" checked={followUpNeeded} onChange={(e) => setFollowUpNeeded(e.target.checked)} />
                  <label htmlFor="followUp">Follow-up needed</label>
                </div>
                {followUpNeeded && (
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Follow-up Date</label>
                    <input type="datetime-local" className={styles.formInput} value={followUpDate} onChange={(e) => setFollowUpDate(e.target.value)} />
                  </div>
                )}

                <div className={styles.formCheckbox}>
                  <input type="checkbox" id="materials" checked={materialsSent} onChange={(e) => setMaterialsSent(e.target.checked)} />
                  <label htmlFor="materials">Materials sent</label>
                </div>
                {materialsSent && (
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Materials Description</label>
                    <input type="text" className={styles.formInput} value={materialsDesc} onChange={(e) => setMaterialsDesc(e.target.value)} placeholder="What was sent?" />
                  </div>
                )}

                <div className={styles.formCheckbox}>
                  <input type="checkbox" id="referral" checked={referralMade} onChange={(e) => setReferralMade(e.target.checked)} />
                  <label htmlFor="referral">Referral made</label>
                </div>
                {referralMade && (
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Referred to</label>
                    <input type="text" className={styles.formInput} value={referralTo} onChange={(e) => setReferralTo(e.target.value)} placeholder="Name or department" />
                  </div>
                )}
              </>
            )}
          </>
        )}
        <div className={styles.panelFooter}>
          <button className={styles.btnCancel} onClick={() => { setCallModal(null); setAutoCloseMsg(null) }}>
            {autoCloseMsg ? 'Close' : 'Cancel'}
          </button>
          {!autoCloseMsg && (
            <button className={styles.btnPrimary} onClick={submitCall} disabled={!callOutcome || saving}>
              {saving ? 'Saving...' : 'Save'}
            </button>
          )}
        </div>
      </SidePanel>

      {/* ---------- Email Compose Side Panel ---------- */}
      <SidePanel
        open={!!emailModal}
        title={`Send Email — ${emailModal?.user?.name || ''}`}
        onClose={() => setEmailModal(null)}
      >
        {emailTemplates.length > 0 && (
          <div className={styles.formGroup}>
            <label className={styles.formLabel}>Template</label>
            <select className={styles.formSelect} onChange={(e) => selectTemplate(e.target.value)}>
              <option value="">Select a template...</option>
              {emailTemplates.map((t) => (
                <option key={t.id} value={t.id}>{t.name}</option>
              ))}
            </select>
          </div>
        )}
        <div className={styles.formGroup}>
          <label className={styles.formLabel}>To</label>
          <input type="email" className={styles.formInput} value={emailTo} onChange={(e) => setEmailTo(e.target.value)} />
        </div>
        <div className={styles.formGroup}>
          <label className={styles.formLabel}>Subject</label>
          <input type="text" className={styles.formInput} value={emailSubject} onChange={(e) => setEmailSubject(e.target.value)} />
        </div>
        <div className={styles.formGroup}>
          <label className={styles.formLabel}>Body</label>
          <textarea className={styles.formTextarea} style={{ minHeight: 160 }} value={emailBody} onChange={(e) => setEmailBody(e.target.value)} />
        </div>
        <div className={styles.panelFooter}>
          <button className={styles.btnCancel} onClick={() => setEmailModal(null)}>Cancel</button>
          <button className={styles.btnPrimary} onClick={submitEmail} disabled={!emailTo || !emailSubject || !emailBody || saving}>
            {saving ? 'Sending...' : 'Send Email'}
          </button>
        </div>
      </SidePanel>

      {/* ---------- Schedule Follow-Up Side Panel ---------- */}
      <SidePanel
        open={!!scheduleModal}
        title="Schedule Follow-up"
        onClose={() => setScheduleModal(null)}
        width={400}
      >
        <div className={styles.formGroup}>
          <label className={styles.formLabel}>Pick a date</label>
          <input type="datetime-local" className={styles.formInput} value={scheduleDate} onChange={(e) => setScheduleDate(e.target.value)} />
        </div>
        <div className={styles.formGroup}>
          <label className={styles.formLabel}>Or choose a quick option</label>
          <div className={styles.quickButtons}>
            <button className={styles.quickBtn} onClick={() => submitSchedule(1)}>Tomorrow</button>
            <button className={styles.quickBtn} onClick={() => submitSchedule(3)}>In 3 days</button>
            <button className={styles.quickBtn} onClick={() => submitSchedule(7)}>In 1 week</button>
            <button className={styles.quickBtn} onClick={() => submitSchedule(14)}>In 2 weeks</button>
          </div>
        </div>
        <div className={styles.panelFooter}>
          <button className={styles.btnCancel} onClick={() => setScheduleModal(null)}>Cancel</button>
          <button className={styles.btnPrimary} onClick={() => submitSchedule(null)} disabled={!scheduleDate || saving}>
            {saving ? 'Saving...' : 'Set Date'}
          </button>
        </div>
      </SidePanel>

      {/* ---------- Resolve Side Panel ---------- */}
      <SidePanel
        open={!!resolveModal}
        title={`Resolve — ${resolveModal?.user?.name || ''}`}
        onClose={() => setResolveModal(null)}
        width={440}
      >
        <div className={styles.formGroup}>
          <label className={styles.formLabel}>Reason</label>
          <select className={styles.formSelect} value={resolveReason} onChange={(e) => setResolveReason(e.target.value)}>
            {CLOSE_REASONS.map((r) => (
              <option key={r.value} value={r.value}>{r.label}</option>
            ))}
          </select>
        </div>
        <div className={styles.formGroup}>
          <label className={styles.formLabel}>Notes (optional)</label>
          <textarea className={styles.formTextarea} value={resolveNote} onChange={(e) => setResolveNote(e.target.value)} placeholder="Additional details..." />
        </div>
        <div className={styles.panelFooter}>
          <button className={styles.btnCancel} onClick={() => setResolveModal(null)}>Cancel</button>
          <button className={styles.btnPrimary} onClick={submitResolve} disabled={saving}>
            {saving ? 'Closing...' : 'Close Item'}
          </button>
        </div>
      </SidePanel>
    </>
  )
}

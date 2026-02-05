import styles from './Pagination.module.css'

export default function Pagination({ offset, limit, total, onChange }) {
  const currentPage = Math.floor(offset / limit) + 1
  const totalPages = Math.ceil(total / limit)
  const startItem = offset + 1
  const endItem = Math.min(offset + limit, total)

  if (totalPages <= 1) {
    return (
      <div className={styles.pagination}>
        <span className={styles.info}>
          {total > 0 ? `1-${total} of ${total}` : 'No results'}
        </span>
      </div>
    )
  }

  const pages = []
  if (totalPages <= 7) {
    for (let i = 1; i <= totalPages; i++) pages.push(i)
  } else {
    pages.push(1)
    if (currentPage > 3) pages.push('...')
    for (let i = Math.max(2, currentPage - 1); i <= Math.min(totalPages - 1, currentPage + 1); i++) {
      pages.push(i)
    }
    if (currentPage < totalPages - 2) pages.push('...')
    pages.push(totalPages)
  }

  return (
    <div className={styles.pagination}>
      <span className={styles.info}>
        {startItem}-{endItem} of {total.toLocaleString()}
      </span>
      <div className={styles.btns}>
        {pages.map((p, i) =>
          p === '...' ? (
            <span key={`ellipsis-${i}`} className={styles.ellipsis}>...</span>
          ) : (
            <button
              key={p}
              className={`${styles.pageBtn} ${p === currentPage ? styles.active : ''}`}
              onClick={() => onChange((p - 1) * limit)}
            >
              {p}
            </button>
          )
        )}
      </div>
    </div>
  )
}

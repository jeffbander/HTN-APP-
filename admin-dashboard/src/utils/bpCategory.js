export function classifyBP(systolic, diastolic) {
  if (systolic > 180 || diastolic > 120) {
    return { label: 'Crisis', color: '#b71c1c', css: 'crisis' }
  }
  if (systolic >= 140 || diastolic >= 90) {
    return { label: 'Stage 2', color: '#f44336', css: 'stage2' }
  }
  if (systolic >= 130 || diastolic >= 80) {
    return { label: 'Stage 1', color: '#ff9800', css: 'stage1' }
  }
  if (systolic >= 120 && diastolic < 80) {
    return { label: 'Elevated', color: '#fdd835', css: 'elevated' }
  }
  return { label: 'Normal', color: '#4caf50', css: 'normal' }
}

export const BP_CATEGORIES = [
  { label: 'Normal', range: '<120/80', color: '#4caf50', css: 'normal' },
  { label: 'Elevated', range: '120-129/<80', color: '#fdd835', css: 'elevated' },
  { label: 'Stage 1', range: '130-139/80-89', color: '#ff9800', css: 'stage1' },
  { label: 'Stage 2', range: '140+/90+', color: '#f44336', css: 'stage2' },
  { label: 'Crisis', range: '>180/>120', color: '#b71c1c', css: 'crisis' },
]

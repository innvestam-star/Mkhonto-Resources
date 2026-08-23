import type { SupabaseClient } from '@supabase/supabase-js'

import type {
  CreateVerificationInput,
  DuplicateCandidate,
  DuplicateDecision,
  IntelligenceEntityType,
  IntelligenceImportBatch,
  IntelligenceImportRow,
  IntelligenceSourceInput,
  ImportBatchStats,
  ImportBatchStatus,
  ImportRowStatus,
} from './types'

type ListOptions = {
  limit?: number
  offset?: number
}

function pageRange(options: ListOptions = {}) {
  const limit = Math.min(Math.max(options.limit ?? 50, 1), 200)
  const offset = Math.max(options.offset ?? 0, 0)
  return { from: offset, to: offset + limit - 1 }
}

export async function listImportBatches(
  supabase: SupabaseClient,
  organisationId: string,
  status?: ImportBatchStatus,
  options: ListOptions = {},
) {
  const { from, to } = pageRange(options)
  let query = supabase
    .from('intelligence_import_batches')
    .select('*')
    .eq('organisation_id', organisationId)
    .order('created_at', { ascending: false })
    .range(from, to)

  if (status) query = query.eq('status', status)

  const { data, error } = await query
  if (error) throw error
  return (data ?? []) as IntelligenceImportBatch[]
}

export async function listImportRows(
  supabase: SupabaseClient,
  batchId: string,
  filters: {
    status?: ImportRowStatus
    entityType?: IntelligenceEntityType
  } = {},
  options: ListOptions = {},
) {
  const { from, to } = pageRange(options)
  let query = supabase
    .from('intelligence_import_rows')
    .select('*')
    .eq('batch_id', batchId)
    .order('source_row_number', { ascending: true })
    .range(from, to)

  if (filters.status) query = query.eq('validation_status', filters.status)
  if (filters.entityType) query = query.eq('entity_type', filters.entityType)

  const { data, error } = await query
  if (error) throw error
  return (data ?? []) as IntelligenceImportRow[]
}

export async function listDuplicateCandidates(
  supabase: SupabaseClient,
  importRowId: string,
) {
  const { data, error } = await supabase
    .from('intelligence_duplicate_candidates')
    .select('*')
    .eq('import_row_id', importRowId)
    .order('match_score', { ascending: false })

  if (error) throw error
  return (data ?? []) as DuplicateCandidate[]
}

export async function detectDuplicates(
  supabase: SupabaseClient,
  importRowId: string,
) {
  const { data, error } = await supabase.rpc('detect_intelligence_duplicates', {
    p_import_row_id: importRowId,
  })

  if (error) throw error
  return Number(data ?? 0)
}

export async function refreshImportBatchStats(
  supabase: SupabaseClient,
  batchId: string,
) {
  const { data, error } = await supabase.rpc('refresh_intelligence_import_batch_stats', {
    p_batch_id: batchId,
  })

  if (error) throw error
  const row = Array.isArray(data) ? data[0] : data
  return row as ImportBatchStats | null
}

export async function decideDuplicateCandidate(
  supabase: SupabaseClient,
  input: {
    candidateId: string
    decision: Exclude<DuplicateDecision, 'pending'>
    decidedBy: string
    notes?: string
  },
) {
  const { data, error } = await supabase
    .from('intelligence_duplicate_candidates')
    .update({
      decision: input.decision,
      decided_by: input.decidedBy,
      decided_at: new Date().toISOString(),
      notes: input.notes ?? '',
    })
    .eq('id', input.candidateId)
    .select('*')
    .single()

  if (error) throw error
  return data as DuplicateCandidate
}

export async function reviewImportRow(
  supabase: SupabaseClient,
  input: {
    rowId: string
    status: Extract<ImportRowStatus, 'approved' | 'rejected'>
    reviewedBy: string
  },
) {
  const { data, error } = await supabase
    .from('intelligence_import_rows')
    .update({
      validation_status: input.status,
      reviewed_by: input.reviewedBy,
      reviewed_at: new Date().toISOString(),
    })
    .eq('id', input.rowId)
    .select('*')
    .single()

  if (error) throw error
  return data as IntelligenceImportRow
}

export async function updateImportBatchMapping(
  supabase: SupabaseClient,
  input: {
    batchId: string
    columnMapping: Record<string, unknown>
  },
) {
  const { data, error } = await supabase
    .from('intelligence_import_batches')
    .update({
      column_mapping: input.columnMapping,
      status: 'validating',
      started_at: new Date().toISOString(),
    })
    .eq('id', input.batchId)
    .select('*')
    .single()

  if (error) throw error
  return data as IntelligenceImportBatch
}

export async function createVerificationRecord(
  supabase: SupabaseClient,
  input: CreateVerificationInput,
) {
  const targetCount = [
    input.counterparty_id,
    input.contact_id,
    input.mine_id,
    input.laboratory_id,
  ].filter(Boolean).length

  if (targetCount !== 1) {
    throw new Error('Verification records require exactly one target entity')
  }

  const { data, error } = await supabase
    .from('verification_records')
    .insert({
      ...input,
      notes: input.notes ?? '',
    })
    .select('*')
    .single()

  if (error) throw error
  return data
}

export async function createIntelligenceSource(
  supabase: SupabaseClient,
  input: IntelligenceSourceInput,
) {
  const { data, error } = await supabase
    .from('intelligence_sources')
    .insert({
      ...input,
      source_sheet: input.source_sheet ?? '',
      source_row: input.source_row ?? '',
      notes: input.notes ?? '',
    })
    .select('*')
    .single()

  if (error) throw error
  return data
}

export async function listCounterpartiesForIntelligence(
  supabase: SupabaseClient,
  organisationId: string,
  search?: string,
  options: ListOptions = {},
) {
  const { from, to } = pageRange(options)
  let query = supabase
    .from('counterparties')
    .select('id,legal_name,trading_name,registration_number,website_domain,general_email,main_telephone,company_status,verification_status,confidence_score,last_verified_at,created_at,updated_at')
    .eq('organisation_id', organisationId)
    .order('legal_name', { ascending: true })
    .range(from, to)

  if (search?.trim()) {
    const term = search.trim().replace(/[,%()]/g, ' ')
    query = query.or(`legal_name.ilike.%${term}%,trading_name.ilike.%${term}%,registration_number.ilike.%${term}%,website_domain.ilike.%${term}%`)
  }

  const { data, error } = await query
  if (error) throw error
  return data ?? []
}

export async function listMinesForIntelligence(
  supabase: SupabaseClient,
  organisationId: string,
  options: ListOptions = {},
) {
  const { from, to } = pageRange(options)
  const { data, error } = await supabase
    .from('mines')
    .select('id,name,mine_type,mine_status,country,province_state,municipality,nearest_town,verification_status,confidence_score,last_verified_at,estimated_available_tonnage_mt,estimated_production_capacity_mt_month')
    .eq('organisation_id', organisationId)
    .order('name', { ascending: true })
    .range(from, to)

  if (error) throw error
  return data ?? []
}

export async function listLaboratoriesForIntelligence(
  supabase: SupabaseClient,
  organisationId: string,
  options: ListOptions = {},
) {
  const { from, to } = pageRange(options)
  const { data, error } = await supabase
    .from('laboratories')
    .select('id,laboratory_name,city,province_state,country,accreditation_body,accreditation_number,accreditation_expiry,preferred_status,verification_status,last_verified_at,typical_turnaround')
    .eq('organisation_id', organisationId)
    .order('laboratory_name', { ascending: true })
    .range(from, to)

  if (error) throw error
  return data ?? []
}

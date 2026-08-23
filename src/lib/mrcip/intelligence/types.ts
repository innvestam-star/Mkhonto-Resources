export type IntelligenceEntityType =
  | 'counterparty'
  | 'contact'
  | 'mine'
  | 'laboratory'
  | 'commodity'
  | 'outreach'
  | 'other'

export type ImportBatchStatus =
  | 'uploaded'
  | 'mapping'
  | 'validating'
  | 'review_required'
  | 'ready'
  | 'importing'
  | 'completed'
  | 'partial_failure'
  | 'failed'
  | 'cancelled'

export type ImportRowStatus =
  | 'pending'
  | 'valid'
  | 'warning'
  | 'error'
  | 'duplicate_review'
  | 'approved'
  | 'rejected'
  | 'imported'

export type DuplicateDecision =
  | 'pending'
  | 'merge'
  | 'keep_separate'
  | 'not_duplicate'
  | 'rejected'

export type VerificationStatus =
  | 'unverified'
  | 'partially_verified'
  | 'public_source_confirmed'
  | 'contact_confirmed'
  | 'documentation_verified'
  | 'commercially_verified'
  | 'verified_directly'
  | 'failed'
  | 'expired'
  | 'rejected'

export type CounterpartyRole =
  | 'producer'
  | 'seller'
  | 'buyer'
  | 'trader'
  | 'broker'
  | 'facilitator'
  | 'logistics_provider'
  | 'transporter'
  | 'laboratory'
  | 'inspection_company'
  | 'surveyor'
  | 'mining_contractor'
  | 'equipment_supplier'
  | 'financial_institution'
  | 'insurance'
  | 'investor'
  | 'partner'

export type JsonObject = Record<string, unknown>

export interface IntelligenceImportBatch {
  id: string
  organisation_id: string
  source_file_name: string
  source_file_type: 'xlsx' | 'csv'
  source_checksum: string
  source_document_id: string | null
  source_description: string
  status: ImportBatchStatus
  column_mapping: JsonObject
  total_rows: number
  valid_rows: number
  warning_rows: number
  error_rows: number
  duplicate_rows: number
  imported_rows: number
  started_at: string | null
  completed_at: string | null
  created_by: string
  created_at: string
  updated_at: string
}

export interface IntelligenceImportRow {
  id: string
  organisation_id: string
  batch_id: string
  source_sheet: string
  source_row_number: number
  entity_type: IntelligenceEntityType
  raw_data: JsonObject
  normalized_data: JsonObject
  validation_status: ImportRowStatus
  validation_messages: unknown[] | JsonObject
  target_table: string
  target_record_id: string | null
  imported_at: string | null
  reviewed_by: string | null
  reviewed_at: string | null
  created_at: string
}

export interface DuplicateCandidate {
  id: string
  organisation_id: string
  import_row_id: string
  candidate_counterparty_id: string | null
  candidate_contact_id: string | null
  candidate_mine_id: string | null
  candidate_laboratory_id: string | null
  match_score: number
  matched_fields: JsonObject
  decision: DuplicateDecision
  decided_by: string | null
  decided_at: string | null
  notes: string
  created_at: string
}

export interface ImportBatchStats {
  total_rows: number
  valid_rows: number
  warning_rows: number
  error_rows: number
  duplicate_rows: number
  imported_rows: number
}

export interface VerificationTarget {
  counterparty_id?: string | null
  contact_id?: string | null
  mine_id?: string | null
  laboratory_id?: string | null
}

export interface CreateVerificationInput extends VerificationTarget {
  organisation_id: string
  verification_type: string
  status: VerificationStatus
  verified_at?: string | null
  verified_by?: string | null
  source_id?: string | null
  valid_until?: string | null
  confidence_score: number
  notes?: string
}

export interface IntelligenceSourceInput extends VerificationTarget {
  organisation_id: string
  commodity_id?: string | null
  product_id?: string | null
  source_name: string
  source_url: string
  source_type: string
  discovered_at?: string | null
  imported_at?: string | null
  last_checked_at?: string | null
  captured_by?: string | null
  confidence_score: number
  verification_status: VerificationStatus
  source_document_id?: string | null
  source_sheet?: string
  source_row?: string
  notes?: string
  import_row_id?: string | null
}

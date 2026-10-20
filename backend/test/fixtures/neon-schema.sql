-- Schema-only fixture read from the imported Neon database; no application data.
CREATE SEQUENCE public."employee_aquarium_logins_id_seq";
CREATE SEQUENCE public."historical_payroll_components_import_id_seq";
CREATE SEQUENCE public."historical_payroll_import_id_seq";
CREATE SEQUENCE public."historical_statutory_import_id_seq";
CREATE SEQUENCE public."historical_unpaid_import_id_seq";
CREATE SEQUENCE public."payroll_import_audit_id_seq";
CREATE TABLE public."branch_activity_logs" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "branch_id" text NOT NULL,
  "action" text NOT NULL,
  "employee_id" text,
  "employee_name" text,
  "opened_at" timestamp with time zone DEFAULT now() NOT NULL,
  "closed_at" timestamp with time zone,
  "details" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE public."branches" (
  "id" text NOT NULL,
  "name" text DEFAULT ''::text NOT NULL,
  "location" text DEFAULT ''::text NOT NULL,
  "username" text DEFAULT ''::text NOT NULL,
  "password" text DEFAULT ''::text NOT NULL,
  "address" text DEFAULT ''::text NOT NULL,
  "phone" text DEFAULT ''::text NOT NULL,
  "is_active" boolean DEFAULT true NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE public."app_user" (
  "username" text NOT NULL,
  "role" text NOT NULL,
  "branch_id" text,
  "employee_id" text,
  "display_name" text DEFAULT ''::text NOT NULL,
  "is_active" boolean DEFAULT true NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "first_login" boolean DEFAULT true NOT NULL,
  "email" text,
  "passwordHash" text,
  "must_change_password" boolean DEFAULT false NOT NULL,
  "password_changed_at" timestamp with time zone,
  "temporary_password_expires_at" timestamp with time zone,
  "otpHash" text,
  "otpExpiresAt" timestamp with time zone,
  "otpAttempts" integer DEFAULT 0 NOT NULL,
  "otpLastSentAt" timestamp with time zone,
  "otpVerifiedAt" timestamp with time zone,
  CHECK ((role = ANY (ARRAY['admin'::text, 'branch'::text, 'employee'::text]))),
  PRIMARY KEY (username)
);
CREATE TABLE public."staff_transfer_history" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "employee_id" text NOT NULL,
  "employee_name" text,
  "from_branch_id" text NOT NULL,
  "to_branch_id" text NOT NULL,
  "effective_date" date DEFAULT CURRENT_DATE NOT NULL,
  "reason" text,
  "transferred_at" timestamp with time zone DEFAULT now() NOT NULL,
  "transferred_by" text NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE public."employees" (
  "employee_id" text NOT NULL,
  "name" text DEFAULT ''::text NOT NULL,
  "designation" text DEFAULT ''::text NOT NULL,
  "department" text DEFAULT ''::text NOT NULL,
  "email" text DEFAULT ''::text NOT NULL,
  "new_ic_no" text DEFAULT ''::text NOT NULL,
  "bank_code" text DEFAULT ''::text NOT NULL,
  "bank_account" text DEFAULT ''::text NOT NULL,
  "epf_no" text DEFAULT ''::text NOT NULL,
  "address" text DEFAULT ''::text NOT NULL,
  "joining_date" date,
  "is_active" boolean DEFAULT true NOT NULL,
  "branch_id" text DEFAULT ''::text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "socso_no" text,
  "phone" text,
  "is_management_staff" boolean DEFAULT false NOT NULL,
  "payroll_branch_id" text,
  "is_temp_staff" boolean DEFAULT false NOT NULL,
  "is_other_staff" boolean DEFAULT false NOT NULL,
  "photo_url" text,
  "birthday" date,
  "is_support_staff" boolean DEFAULT false NOT NULL,
  "resigned_at" timestamp with time zone,
  "first_name" text,
  "last_name" text,
  "employment_status" text DEFAULT 'active'::text NOT NULL,
  PRIMARY KEY (employee_id),
  CHECK ((employment_status = ANY (ARRAY['active'::text, 'resigned'::text, 'transferred'::text, 'vacation'::text])))
);
CREATE TABLE public."attendance" (
  "id" text DEFAULT (gen_random_uuid())::text NOT NULL,
  "employee_id" text NOT NULL,
  "branch_id" text NOT NULL,
  "attendance_date" date NOT NULL,
  "check_in" text DEFAULT '-'::text,
  "check_out" text DEFAULT '-'::text,
  "status" text DEFAULT 'Absent'::text NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "morning_in" text,
  "morning_out" text,
  "afternoon_in" text,
  "afternoon_out" text,
  "evening_in" text,
  "evening_out" text,
  "remarks" text,
  "work_minutes" integer DEFAULT 0,
  "break_minutes" integer DEFAULT 0,
  "overtime_minutes" integer DEFAULT 0,
  "net_working_minutes" integer DEFAULT 0,
  "work_duration" text,
  "break_duration" text,
  "overtime_duration" text,
  "net_working_duration" text,
  "ot_authorized" boolean DEFAULT false NOT NULL,
  "overtime_in" text,
  "overtime_out" text,
  "is_submitted" boolean DEFAULT false NOT NULL,
  "submitted_at" timestamp with time zone,
  "submitted_by" text,
  "is_public_holiday" boolean DEFAULT false NOT NULL,
  "is_unpaid" boolean DEFAULT false NOT NULL,
  "ot_requested" boolean DEFAULT false NOT NULL,
  "approved_ot_minutes" integer,
  "ot_manual_override" boolean DEFAULT false NOT NULL,
  CHECK (((approved_ot_minutes IS NULL) OR ((approved_ot_minutes >= 0) AND (approved_ot_minutes <= 1440)))),
  CHECK ((status = ANY (ARRAY['Present'::text, 'Late'::text, 'Early Out'::text, 'Late + Early Out'::text, 'Absent'::text, 'OFF'::text, 'MC'::text, 'PL'::text, 'AL'::text, 'EL'::text, 'PH'::text, 'PH-OFF'::text, 'PH-SPL'::text, 'PH-GUNTI'::text, 'UNPAID'::text]))),
  UNIQUE (employee_id, attendance_date),
  PRIMARY KEY (id)
);
CREATE TABLE public."company_tree_daily_logins" (
  "employee_id" text NOT NULL,
  "login_date" date NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  PRIMARY KEY (employee_id, login_date)
);
CREATE TABLE public."daily_report_branch_pins" (
  "branch_id" text NOT NULL,
  "pin_hash" text NOT NULL,
  "changed_at" timestamp with time zone DEFAULT now() NOT NULL,
  PRIMARY KEY (branch_id)
);
CREATE TABLE public."app_notifications" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "title" text NOT NULL,
  "body" text NOT NULL,
  "notification_type" text DEFAULT 'information'::text NOT NULL,
  "audience" text NOT NULL,
  "branch_id" text,
  "employee_id" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CHECK ((audience = ANY (ARRAY['all'::text, 'branch'::text, 'employee'::text]))),
  PRIMARY KEY (id)
);
CREATE TABLE public."daily_report_pin_attempts" (
  "branch_id" text NOT NULL,
  "failed_attempts" integer DEFAULT 0 NOT NULL,
  "window_started_at" timestamp with time zone DEFAULT now() NOT NULL,
  "locked_until" timestamp with time zone,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  CHECK ((failed_attempts >= 0)),
  PRIMARY KEY (branch_id)
);
CREATE TABLE public."daily_reports" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "branch_id" text NOT NULL,
  "report_date" date NOT NULL,
  "attendance" text DEFAULT ''::text NOT NULL,
  "unpaid_leave" text DEFAULT ''::text NOT NULL,
  "weekly_leave" text DEFAULT ''::text NOT NULL,
  "annual_leave" text DEFAULT ''::text NOT NULL,
  "air_conditioner" text DEFAULT ''::text NOT NULL,
  "maintenance_total" text DEFAULT ''::text NOT NULL,
  "working_condition" text DEFAULT ''::text NOT NULL,
  "service_repair" text DEFAULT ''::text NOT NULL,
  "maintenance_report" text,
  "orsanco" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "report_crew" text,
  "recommendation" text,
  "reported_by" text NOT NULL,
  "branch_stamp" text,
  "hq_comment" text,
  "reviewed_at" timestamp with time zone,
  "reviewed_by" text,
  "submitted_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  UNIQUE (branch_id, report_date),
  PRIMARY KEY (id)
);
CREATE TABLE public."daily_rosters" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "branch_id" text NOT NULL,
  "employee_id" text NOT NULL,
  "roster_date" date NOT NULL,
  "assignment_type" text NOT NULL,
  "shift_start" time without time zone,
  "shift_end" time without time zone,
  "break_minutes" integer DEFAULT 0 NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  CHECK ((assignment_type = ANY (ARRAY['SHIFT'::text, 'OFF'::text, 'MC'::text, 'PL'::text, 'AL'::text, 'EL'::text, 'PH'::text, 'UNPAID'::text]))),
  CHECK (((break_minutes >= 0) AND (break_minutes <= 720))),
  CHECK ((((assignment_type = 'SHIFT'::text) AND (shift_start IS NOT NULL) AND (shift_end IS NOT NULL)) OR ((assignment_type <> 'SHIFT'::text) AND (shift_start IS NULL) AND (shift_end IS NULL)))),
  UNIQUE (branch_id, employee_id, roster_date),
  PRIMARY KEY (id)
);
CREATE TABLE public."employee_aquarium_logins" (
  "id" bigint NOT NULL,
  "employee_id" text NOT NULL,
  "logged_in_at" timestamp with time zone DEFAULT now() NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE public."employee_aquariums" (
  "employee_id" text NOT NULL,
  "total_feed" integer DEFAULT 0 NOT NULL,
  "fish_count" integer DEFAULT 2 NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "available_food" integer DEFAULT 0 NOT NULL,
  "dead_fish_count" integer DEFAULT 0 NOT NULL,
  "fish_birth_dates" jsonb DEFAULT '[]'::jsonb NOT NULL,
  "last_login_at" timestamp with time zone,
  "last_decay_at" timestamp with time zone,
  "reward_login_days" integer DEFAULT 0 NOT NULL,
  "last_reward_login_date" date,
  CHECK (((dead_fish_count >= 0) AND (dead_fish_count <= 10))),
  CHECK (((fish_count >= 0) AND (fish_count <= 10))),
  CHECK ((total_feed >= 0)),
  PRIMARY KEY (employee_id)
);
CREATE TABLE public."employee_ea_forms" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "employee_id" text NOT NULL,
  "tax_year" integer NOT NULL,
  "form_data" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "generated_by" text,
  "generated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  CHECK (((tax_year >= 2000) AND (tax_year <= 2100))),
  UNIQUE (employee_id, tax_year),
  PRIMARY KEY (id)
);
CREATE TABLE public."employee_requests" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "branch_id" text NOT NULL,
  "name" text NOT NULL,
  "designation" text,
  "department" text,
  "email" text,
  "new_ic_no" text,
  "bank_code" text,
  "bank_account" text,
  "phone" text,
  "address" text,
  "joining_date" date,
  "status" text DEFAULT 'PENDING'::text NOT NULL,
  "assigned_employee_id" text,
  "admin_note" text,
  "requested_at" timestamp with time zone DEFAULT now() NOT NULL,
  "reviewed_at" timestamp with time zone,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CHECK ((status = ANY (ARRAY['PENDING'::text, 'APPROVED'::text, 'REJECTED'::text]))),
  PRIMARY KEY (id)
);
CREATE TABLE public."employee_salary_defaults" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "employee_id" text NOT NULL,
  "basic_salary" numeric(12,2) DEFAULT 0.00 NOT NULL,
  "fw_salary" numeric(12,2) DEFAULT 0.00 NOT NULL,
  "elaun_kedatangan" numeric(12,2) DEFAULT 0.00 NOT NULL,
  "elaun_perkhidmatan" numeric(12,2) DEFAULT 0.00 NOT NULL,
  "elaun_kerajinan" numeric(12,2) DEFAULT 0.00 NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "inc_details" text,
  "epf_category" text DEFAULT 'normal'::text NOT NULL,
  "eis_applicable" boolean DEFAULT true NOT NULL,
  "address" text,
  "zakat" numeric(12,2) DEFAULT 0 NOT NULL,
  "epf_enabled" boolean DEFAULT true NOT NULL,
  "eis_enabled" boolean DEFAULT true NOT NULL,
  "socso_enabled" boolean DEFAULT true NOT NULL,
  "socso_category" text DEFAULT 'type1'::text NOT NULL,
  "elaun_makanan" numeric(12,2) DEFAULT 0 NOT NULL,
  "pcb" numeric(12,2) DEFAULT 0 NOT NULL,
  CHECK ((socso_category = ANY (ARRAY['type1'::text, 'type2'::text]))),
  UNIQUE (employee_id),
  PRIMARY KEY (id)
);
CREATE TABLE public."historical_payroll_components_import" (
  "id" bigint NOT NULL,
  "employee_id" text NOT NULL,
  "period" date NOT NULL,
  "ul" numeric DEFAULT 0,
  "um" numeric DEFAULT 0,
  "p01" numeric DEFAULT 0,
  "p02" numeric DEFAULT 0,
  "p03" numeric DEFAULT 0,
  "p04" numeric DEFAULT 0,
  "p05" numeric DEFAULT 0,
  "p06" numeric DEFAULT 0,
  "p07" numeric DEFAULT 0,
  "hw15" numeric DEFAULT 0,
  "hw20" numeric DEFAULT 0,
  "import_batch" text DEFAULT 'components_2023_2026'::text NOT NULL,
  "source_row" integer,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "error_message" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "processed_at" timestamp with time zone,
  "zakat" numeric DEFAULT 0,
  "p08" numeric DEFAULT 0,
  CHECK (((period >= '2023-01-01'::date) AND (period <= '2026-07-01'::date))),
  PRIMARY KEY (id)
);
CREATE TABLE public."historical_payroll_import" (
  "id" bigint NOT NULL,
  "employee_id" text NOT NULL,
  "period" date NOT NULL,
  "basic_salary" numeric,
  "import_batch" text DEFAULT 'basic_salary_2023_2026'::text NOT NULL,
  "source_row" integer,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "error_message" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "processed_at" timestamp with time zone,
  CHECK (((period >= '2023-01-01'::date) AND (period <= '2026-07-01'::date))),
  PRIMARY KEY (id)
);
CREATE TABLE public."historical_statutory_import" (
  "id" bigint NOT NULL,
  "employee_id" text NOT NULL,
  "period" date NOT NULL,
  "epf_employee" numeric DEFAULT 0,
  "epf_employer" numeric DEFAULT 0,
  "socso_employee" numeric DEFAULT 0,
  "socso_employer" numeric DEFAULT 0,
  "eis_employee" numeric DEFAULT 0,
  "eis_employer" numeric DEFAULT 0,
  "pcb" numeric DEFAULT 0,
  "import_batch" text DEFAULT 'statutory_2023_2026'::text NOT NULL,
  "source_row" integer,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "error_message" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "processed_at" timestamp with time zone,
  CHECK (((period >= '2023-01-01'::date) AND (period <= '2026-07-01'::date))),
  PRIMARY KEY (id)
);
CREATE TABLE public."july_2026_payroll_import" (
  "employee_id" text NOT NULL,
  "basic_salary" numeric DEFAULT 0,
  "fw_salary" numeric DEFAULT 0,
  "elaun_perkhidmatan" numeric DEFAULT 0,
  "cuti_umum" numeric DEFAULT 0,
  "elaun_kerajinan" numeric DEFAULT 0,
  "elaun_kedatangan" numeric DEFAULT 0,
  "overtime" numeric DEFAULT 0,
  "unpaid_deduction" numeric DEFAULT 0,
  "zakat" numeric DEFAULT 0,
  "epf_employee" numeric DEFAULT 0,
  "socso_employee" numeric DEFAULT 0,
  "eis_employee" numeric DEFAULT 0,
  "pcb" numeric DEFAULT 0,
  "epf_employer" numeric DEFAULT 0,
  "socso_employer" numeric DEFAULT 0,
  "eis_employer" numeric DEFAULT 0,
  PRIMARY KEY (employee_id)
);
CREATE TABLE public."notification_reads" (
  "notification_id" uuid NOT NULL,
  "employee_id" text NOT NULL,
  "read_at" timestamp with time zone DEFAULT now() NOT NULL,
  PRIMARY KEY (notification_id, employee_id)
);
CREATE TABLE public."leave_requests" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "employee_id" text NOT NULL,
  "employee_name" text NOT NULL,
  "branch_id" text NOT NULL,
  "department" text,
  "designation" text,
  "leave_type" text NOT NULL,
  "start_date" date NOT NULL,
  "end_date" date NOT NULL,
  "total_days" integer NOT NULL,
  "reason" text NOT NULL,
  "address_during_leave" text,
  "emergency_phone" text,
  "status" text DEFAULT 'pending_branch'::text NOT NULL,
  "branch_remarks" text,
  "branch_approved_at" timestamp with time zone,
  "branch_approved_by" uuid,
  "branch_approved_name" text,
  "admin_remarks" text,
  "admin_approved_at" timestamp with time zone,
  "admin_approved_by" uuid,
  "submitted_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  CHECK ((end_date >= start_date)),
  CHECK ((leave_type = ANY (ARRAY['Unpaid Leave'::text, 'Emergency Leave'::text, 'Replacement Leave'::text]))),
  CHECK ((status = ANY (ARRAY['pending_branch'::text, 'pending_admin'::text, 'approved'::text, 'rejected'::text]))),
  CHECK ((total_days > 0)),
  PRIMARY KEY (id)
);
CREATE TABLE public."monthly_rosters" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "branch_id" text NOT NULL,
  "employee_id" text NOT NULL,
  "roster_year" integer NOT NULL,
  "roster_month" integer NOT NULL,
  "week_number" integer NOT NULL,
  "shift_start" time without time zone NOT NULL,
  "shift_end" time without time zone NOT NULL,
  "break_minutes" integer DEFAULT 60 NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  CHECK (((break_minutes >= 0) AND (break_minutes <= 720))),
  CHECK (((roster_month >= 1) AND (roster_month <= 12))),
  CHECK (((roster_year >= 2020) AND (roster_year <= 2100))),
  CHECK (((week_number >= 1) AND (week_number <= 5))),
  UNIQUE (branch_id, employee_id, roster_year, roster_month, week_number),
  PRIMARY KEY (id)
);
CREATE TABLE public."notification_devices" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "token" text NOT NULL,
  "employee_id" text,
  "branch_id" text,
  "platform" text DEFAULT 'unknown'::text NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (token)
);
CREATE TABLE public."overtime_requests" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "employee_id" text NOT NULL,
  "employee_name" text NOT NULL,
  "branch_id" text NOT NULL,
  "department" text DEFAULT ''::text NOT NULL,
  "overtime_date" date NOT NULL,
  "shift_start" time without time zone,
  "shift_end" time without time zone,
  "overtime_start" time without time zone NOT NULL,
  "overtime_end" time without time zone NOT NULL,
  "requested_minutes" integer NOT NULL,
  "reason" text NOT NULL,
  "status" text DEFAULT 'pending_branch'::text NOT NULL,
  "approved_minutes" integer,
  "submitted_at" timestamp with time zone DEFAULT now() NOT NULL,
  "reviewed_at" timestamp with time zone,
  "reviewed_by" uuid,
  "branch_approved_at" timestamp with time zone,
  "branch_approved_by" uuid,
  "admin_approved_at" timestamp with time zone,
  "admin_approved_by" uuid,
  "branch_approved_name" text,
  UNIQUE (employee_id, branch_id, overtime_date),
  PRIMARY KEY (id),
  CHECK (((approved_minutes IS NULL) OR ((approved_minutes >= 0) AND (approved_minutes <= 1440)))),
  CHECK (((branch_approved_at IS NULL) OR (NULLIF(TRIM(BOTH FROM branch_approved_name), ''::text) IS NOT NULL))),
  CHECK ((length(TRIM(BOTH FROM reason)) > 0)),
  CHECK (((requested_minutes >= 1) AND (requested_minutes <= 1440))),
  CHECK ((status = ANY (ARRAY['pending_branch'::text, 'pending_admin'::text, 'approved'::text, 'rejected'::text])))
);
CREATE TABLE public."historical_unpaid_import" (
  "id" bigint NOT NULL,
  "employee_id" text NOT NULL,
  "period" date NOT NULL,
  "m01" numeric DEFAULT 0,
  "m02" numeric DEFAULT 0,
  "m03" numeric DEFAULT 0,
  "import_batch" text DEFAULT 'unpaid_2023_2026'::text NOT NULL,
  "source_row" integer,
  "status" text DEFAULT 'pending'::text NOT NULL,
  "error_message" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "processed_at" timestamp with time zone,
  CHECK (((period >= '2023-01-01'::date) AND (period <= '2026-07-01'::date))),
  PRIMARY KEY (id)
);
CREATE TABLE public."payroll_import_audit" (
  "id" bigint NOT NULL,
  "import_type" text NOT NULL,
  "batch_name" text,
  "source_name" text,
  "action" text NOT NULL,
  "affected_rows" integer DEFAULT 0 NOT NULL,
  "period_start" date,
  "period_end" date,
  "details" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "created_by" uuid,
  PRIMARY KEY (id)
);
CREATE TABLE public."payslip_release_schedules" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "payroll_month" date NOT NULL,
  "release_at" timestamp with time zone NOT NULL,
  "increment_employees" jsonb DEFAULT '[]'::jsonb NOT NULL,
  "scheduled_by" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "released_at" timestamp with time zone,
  UNIQUE (payroll_month),
  PRIMARY KEY (id),
  CHECK ((jsonb_typeof(increment_employees) = 'array'::text))
);
CREATE TABLE public."payroll" (
  "id" text DEFAULT (gen_random_uuid())::text NOT NULL,
  "employee_id" text NOT NULL,
  "period" date NOT NULL,
  "basic_salary" numeric(12,2) DEFAULT 0 NOT NULL,
  "elaun_kedatangan" numeric(12,2) DEFAULT 0 NOT NULL,
  "elaun_perkhidmatan" numeric(12,2) DEFAULT 0 NOT NULL,
  "elaun_kerajinan" numeric(12,2) DEFAULT 0 NOT NULL,
  "overtime" numeric(12,2) DEFAULT 0 NOT NULL,
  "cuti_umum" numeric(12,2) DEFAULT 0 NOT NULL,
  "epf_employee" numeric(12,2) DEFAULT 0 NOT NULL,
  "socso_employee" numeric(12,2) DEFAULT 0 NOT NULL,
  "eis_employee" numeric(12,2) DEFAULT 0 NOT NULL,
  "pcb" numeric(12,2) DEFAULT 0 NOT NULL,
  "zakat" numeric(12,2) DEFAULT 0 NOT NULL,
  "epf_employer" numeric(12,2) DEFAULT 0 NOT NULL,
  "socso_employer" numeric(12,2) DEFAULT 0 NOT NULL,
  "eis_employer" numeric(12,2) DEFAULT 0 NOT NULL,
  "new_ic_no" text DEFAULT ''::text NOT NULL,
  "bank_code" text DEFAULT ''::text NOT NULL,
  "bank_account" text DEFAULT ''::text NOT NULL,
  "remarks" text,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  "fw_salary" numeric(12,2) DEFAULT 0 NOT NULL,
  "late_deduction" numeric(12,2) DEFAULT 0 NOT NULL,
  "unpaid_deduction" numeric(12,2) DEFAULT 0 NOT NULL,
  "bonus" text,
  "commission" text,
  "other_earnings" text,
  "advance" numeric(12,2) DEFAULT 0 NOT NULL,
  "elaun_makanan" numeric(12,2) DEFAULT 0 NOT NULL,
  "is_published" boolean DEFAULT false NOT NULL,
  "published_at" timestamp with time zone,
  "published_by" text,
  "release_at" timestamp with time zone,
  UNIQUE (employee_id, period),
  PRIMARY KEY (id)
);
CREATE OR REPLACE FUNCTION public.normalized_branch_key(value text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case regexp_replace(lower(trim(coalesce(value, ''))), '[^a-z0-9]', '', 'g')
    when 'hbsp' then 'sungaipetani'
    when 'hpspfrn' then 'sungaipetani'
    when 'hbspfrn' then 'sungaipetani'
    when 'hbamj' then 'amanjaya'
    when 'hbamjfrn' then 'amanjaya'
    when 'hbas' then 'alorsetar'
    when 'hbasfrn' then 'alorsetar'
    when 'hbastana' then 'astana'
    when 'hbastanafrn' then 'astana'
    when 'hbgurun' then 'gurun'
    when 'hbgurunfrn' then 'gurun'
    when 'hbjitra' then 'jitra'
    when 'hbjitrafrn' then 'jitra'
    when 'hbperai' then 'prai'
    when 'hbperaifrn' then 'prai'
    when 'hbkulim' then 'kulim'
    when 'hbkulimfrn' then 'kulim'
    when 'hblkw' then 'langkawi'
    when 'hblkwfrn' then 'langkawi'
    else regexp_replace(lower(trim(coalesce(value, ''))), '[^a-z0-9]', '', 'g')
  end;
$function$
;
CREATE OR REPLACE FUNCTION public.enforce_leave_request_approval()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at = now();

  if new.status = 'pending_admin' then
    if old.status <> 'pending_branch'
       or new.branch_approved_at is null
       or nullif(trim(new.branch_approved_name), '') is null
       or nullif(trim(new.branch_remarks), '') is null then
      raise exception 'Complete branch approval is required';
    end if;
  elsif new.status = 'approved' then
    if old.status <> 'pending_admin'
       or new.admin_approved_at is null
       or nullif(trim(new.admin_remarks), '') is null then
      raise exception 'Complete admin approval is required';
    end if;
  elsif new.status = 'rejected' then
    if old.status = 'pending_branch'
       and nullif(trim(new.branch_remarks), '') is null then
      raise exception 'Branch remarks are required';
    elsif old.status = 'pending_admin'
       and nullif(trim(new.admin_remarks), '') is null then
      raise exception 'Admin remarks are required';
    end if;
  end if;

  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.ensure_branch_ot_approver_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  prior_name text;
begin
  if tg_op = 'UPDATE' then
    prior_name := nullif(trim(old.branch_approved_name), '');
  end if;
  if new.branch_approved_at is not null
     and nullif(trim(new.branch_approved_name), '') is null then
    new.branch_approved_name := coalesce(
      prior_name,
      nullif(trim(new.branch_id), ''),
      'Branch approver'
    );
  end if;
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.normalize_historical_components_period()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin new.period:=date_trunc('month',new.period)::date; return new; end $function$
;
CREATE OR REPLACE FUNCTION public.normalize_historical_payroll_import_period()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  new.period := date_trunc('month', new.period)::date;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.normalize_historical_statutory_period()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
 new.period := date_trunc('month',new.period)::date;
 return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.normalize_historical_unpaid_period()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
 new.period := date_trunc('month',new.period)::date;
 return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
    new.updated_at = now();
    return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.sync_employee_resigned_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  -- Preserve compatibility with callers that still update only is_active.
  if tg_op = 'UPDATE'
     and new.is_active is distinct from old.is_active
     and new.employment_status is not distinct from old.employment_status then
    new.employment_status := case when new.is_active then 'active' else 'resigned' end;
  end if;

  new.is_active := new.employment_status in ('active', 'vacation');

  if new.employment_status = 'resigned' then
    if tg_op = 'INSERT'
       or old.employment_status is distinct from 'resigned'
       or old.resigned_at is null then
      new.resigned_at := now();
    end if;
  else
    new.resigned_at := null;
  end if;

  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.process_historical_basic_salary(p_batch text DEFAULT 'basic_salary_2023_2026'::text)
 RETURNS TABLE(imported bigint, skipped_unknown_employee bigint, invalid_rows bigint)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
 v_imported bigint := 0;
 v_skipped bigint := 0;
 v_invalid bigint := 0;
begin
 update public.historical_payroll_import s
 set status='invalid', error_message='Basic salary is missing or negative', processed_at=now()
 where s.import_batch=p_batch and s.status='pending'
   and (s.basic_salary is null or s.basic_salary < 0);
 get diagnostics v_invalid = row_count;

 update public.historical_payroll_import s
 set status='skipped', error_message='Employee ID not found in employees', processed_at=now()
 where s.import_batch=p_batch and s.status='pending'
   and not exists (select 1 from public.employees e where e.employee_id=s.employee_id);
 get diagnostics v_skipped = row_count;

 insert into public.payroll(employee_id,period,basic_salary)
 select s.employee_id,s.period,s.basic_salary
 from public.historical_payroll_import s
 where s.import_batch=p_batch and s.status='pending'
 on conflict (employee_id,period) do update
 set basic_salary=excluded.basic_salary, updated_at=now();
 get diagnostics v_imported = row_count;

 update public.historical_payroll_import s
 set status='imported', error_message=null, processed_at=now()
 where s.import_batch=p_batch and s.status='pending';

 return query select v_imported,v_skipped,v_invalid;
end $function$
;
CREATE OR REPLACE FUNCTION public.process_historical_payroll_components()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_updated int:=0; v_created int:=0; v_unknown int:=0; v_no_default int:=0;
begin
  with src as (
    select s.employee_id,s.period,
      sum(abs(coalesce(s.ul,0))+abs(coalesce(s.um,0))) late_deduction,
      sum(coalesce(s.p01,0)+coalesce(s.p02,0)) elaun_perkhidmatan,
      sum(coalesce(s.p03,0)) cuti_umum,
      sum(coalesce(s.p04,0)) elaun_kerajinan,
      sum(coalesce(s.p05,0)+coalesce(s.p06,0)+coalesce(s.p07,0)+coalesce(s.p08,0)) elaun_kedatangan,
      sum(coalesce(s.hw15,0)+coalesce(s.hw20,0)) overtime,
      sum(abs(coalesce(s.zakat,0))) zakat
    from historical_payroll_components_import s
    where s.status='pending'
    group by s.employee_id,s.period
  ), upd as (
    update payroll p set
      late_deduction=src.late_deduction,
      elaun_perkhidmatan=src.elaun_perkhidmatan,
      cuti_umum=src.cuti_umum,
      elaun_kerajinan=src.elaun_kerajinan,
      elaun_kedatangan=src.elaun_kedatangan,
      overtime=src.overtime,
      zakat=src.zakat,
      updated_at=now()
    from src
    where p.employee_id=src.employee_id and p.period=src.period
    returning 1
  ) select count(*) into v_updated from upd;

  with src as (
    select s.employee_id,s.period,
      sum(abs(coalesce(s.ul,0))+abs(coalesce(s.um,0))) late_deduction,
      sum(coalesce(s.p01,0)+coalesce(s.p02,0)) elaun_perkhidmatan,
      sum(coalesce(s.p03,0)) cuti_umum,
      sum(coalesce(s.p04,0)) elaun_kerajinan,
      sum(coalesce(s.p05,0)+coalesce(s.p06,0)+coalesce(s.p07,0)+coalesce(s.p08,0)) elaun_kedatangan,
      sum(coalesce(s.hw15,0)+coalesce(s.hw20,0)) overtime,
      sum(abs(coalesce(s.zakat,0))) zakat
    from historical_payroll_components_import s
    where s.status='pending'
    group by s.employee_id,s.period
  ), ins as (
    insert into payroll(employee_id,period,basic_salary,late_deduction,elaun_perkhidmatan,cuti_umum,elaun_kerajinan,elaun_kedatangan,overtime,zakat)
    select src.employee_id,src.period,d.basic_salary,src.late_deduction,src.elaun_perkhidmatan,src.cuti_umum,src.elaun_kerajinan,src.elaun_kedatangan,src.overtime,src.zakat
    from src
    join employees e on e.employee_id=src.employee_id
    join employee_salary_defaults d on d.employee_id=src.employee_id
    where not exists(select 1 from payroll p where p.employee_id=src.employee_id and p.period=src.period)
    returning 1
  ) select count(*) into v_created from ins;

  select count(*) into v_unknown from historical_payroll_components_import s
  where s.status='pending' and not exists(select 1 from employees e where e.employee_id=s.employee_id);

  select count(*) into v_no_default from historical_payroll_components_import s
  where s.status='pending'
    and exists(select 1 from employees e where e.employee_id=s.employee_id)
    and not exists(select 1 from payroll p where p.employee_id=s.employee_id and p.period=s.period)
    and not exists(select 1 from employee_salary_defaults d where d.employee_id=s.employee_id);

  update historical_payroll_components_import s set
    status=case
      when not exists(select 1 from employees e where e.employee_id=s.employee_id) then 'skipped_unknown_employee'
      when not exists(select 1 from payroll p where p.employee_id=s.employee_id and p.period=s.period) then 'skipped_no_salary_default'
      else 'imported'
    end,
    error_message=case
      when not exists(select 1 from employees e where e.employee_id=s.employee_id) then 'Employee not found'
      when not exists(select 1 from payroll p where p.employee_id=s.employee_id and p.period=s.period) then 'Payroll month missing and salary default not found'
      else null
    end,
    processed_at=now()
  where s.status='pending';

  return jsonb_build_object('updated_existing_payroll',v_updated,'created_payroll_from_salary_default',v_created,'skipped_unknown_employee_rows',v_unknown,'skipped_no_salary_default_rows',v_no_default);
end $function$
;
CREATE OR REPLACE FUNCTION public.process_historical_statutory_import()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_updated int:=0; v_created int:=0; v_unknown int:=0;
begin
 with src as (
  select employee_id,period,
   sum(abs(coalesce(epf_employee,0))) epf_employee,sum(abs(coalesce(epf_employer,0))) epf_employer,
   sum(abs(coalesce(socso_employee,0))) socso_employee,sum(abs(coalesce(socso_employer,0))) socso_employer,
   sum(abs(coalesce(eis_employee,0))) eis_employee,sum(abs(coalesce(eis_employer,0))) eis_employer,
   sum(abs(coalesce(pcb,0))) pcb
  from historical_statutory_import where status='pending' group by employee_id,period
 ), upd as (
  update payroll p set epf_employee=src.epf_employee,epf_employer=src.epf_employer,
   socso_employee=src.socso_employee,socso_employer=src.socso_employer,
   eis_employee=src.eis_employee,eis_employer=src.eis_employer,pcb=src.pcb,updated_at=now()
  from src where p.employee_id=src.employee_id and p.period=src.period returning 1
 ) select count(*) into v_updated from upd;

 with src as (
  select employee_id,period,
   sum(abs(coalesce(epf_employee,0))) epf_employee,sum(abs(coalesce(epf_employer,0))) epf_employer,
   sum(abs(coalesce(socso_employee,0))) socso_employee,sum(abs(coalesce(socso_employer,0))) socso_employer,
   sum(abs(coalesce(eis_employee,0))) eis_employee,sum(abs(coalesce(eis_employer,0))) eis_employer,
   sum(abs(coalesce(pcb,0))) pcb
  from historical_statutory_import where status='pending' group by employee_id,period
 ), ins as (
  insert into payroll(employee_id,period,basic_salary,epf_employee,epf_employer,socso_employee,socso_employer,eis_employee,eis_employer,pcb)
  select src.employee_id,src.period,0,src.epf_employee,src.epf_employer,src.socso_employee,src.socso_employer,src.eis_employee,src.eis_employer,src.pcb
  from src join employees e on e.employee_id=src.employee_id
  where not exists(select 1 from payroll p where p.employee_id=src.employee_id and p.period=src.period)
  returning 1
 ) select count(*) into v_created from ins;

 select count(*) into v_unknown from historical_statutory_import s where s.status='pending'
 and not exists(select 1 from employees e where e.employee_id=s.employee_id);

 update historical_statutory_import s set
  status=case when not exists(select 1 from employees e where e.employee_id=s.employee_id)
    then 'skipped_unknown_employee' else 'imported' end,
  error_message=case when not exists(select 1 from employees e where e.employee_id=s.employee_id)
    then 'Employee no longer present' else null end,
  processed_at=now()
 where s.status='pending';

 return jsonb_build_object('updated_existing_payroll',v_updated,'created_payroll_with_zero_basic_salary',v_created,'skipped_unknown_employee_rows',v_unknown);
end $function$
;
CREATE OR REPLACE FUNCTION public.process_historical_unpaid(p_batch text DEFAULT 'unpaid_2023_2026'::text)
 RETURNS TABLE(updated bigint, created bigint, skipped_unknown_employee bigint, skipped_no_salary_default bigint)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_updated bigint:=0; v_created bigint:=0; v_unknown bigint:=0; v_no_default bigint:=0;
begin
 update public.historical_unpaid_import s set status='skipped',error_message='Employee ID not found in employees',processed_at=now()
 where s.import_batch=p_batch and s.status='pending'
 and not exists(select 1 from public.employees e where e.employee_id=s.employee_id);
 get diagnostics v_unknown=row_count;

 with missing as (
 select distinct s.employee_id,s.period from public.historical_unpaid_import s
 where s.import_batch=p_batch and s.status='pending'
 and not exists(select 1 from public.payroll p where p.employee_id=s.employee_id and p.period=s.period)
 and not exists(select 1 from public.employee_salary_defaults d where d.employee_id=s.employee_id))
 update public.historical_unpaid_import s set status='skipped',error_message='Payroll missing and employee salary default not found',processed_at=now()
 from missing m where s.import_batch=p_batch and s.status='pending' and s.employee_id=m.employee_id and s.period=m.period;
 get diagnostics v_no_default=row_count;

 with src as (
 select employee_id,period,sum(abs(coalesce(m01,0))+abs(coalesce(m02,0))+abs(coalesce(m03,0))) unpaid
 from public.historical_unpaid_import where import_batch=p_batch and status='pending' group by employee_id,period),
 ins as (
 insert into public.payroll(employee_id,period,basic_salary,unpaid_deduction)
 select src.employee_id,src.period,d.basic_salary,src.unpaid from src
 join public.employee_salary_defaults d on d.employee_id=src.employee_id
 where not exists(select 1 from public.payroll p where p.employee_id=src.employee_id and p.period=src.period)
 returning 1)
 select count(*) into v_created from ins;

 with src as (
 select employee_id,period,sum(abs(coalesce(m01,0))+abs(coalesce(m02,0))+abs(coalesce(m03,0))) unpaid
 from public.historical_unpaid_import where import_batch=p_batch and status='pending' group by employee_id,period)
 update public.payroll p set unpaid_deduction=src.unpaid,updated_at=now()
 from src where p.employee_id=src.employee_id and p.period=src.period;
 get diagnostics v_updated=row_count;
 v_updated:=v_updated-v_created;

 update public.historical_unpaid_import set status='imported',error_message=null,processed_at=now()
 where import_batch=p_batch and status='pending';
 return query select v_updated,v_created,v_unknown,v_no_default;
end $function$
;
CREATE OR REPLACE FUNCTION public.apply_approved_overtime_request()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
begin
  if new.status = 'approved' then
    if old.status <> 'pending_admin' and old.status <> 'approved' then
      raise exception 'Branch approval is required before admin approval';
    end if;
    if new.branch_approved_at is null
       or nullif(trim(new.branch_approved_name), '') is null then
      raise exception 'Branch approval details are required';
    end if;
    if new.approved_minutes is null then
      raise exception 'Approved OT minutes are required';
    end if;

    update public.attendance
    set ot_requested = true,
        ot_authorized = true,
        approved_ot_minutes = new.approved_minutes
    where employee_id = new.employee_id
      and branch_id = new.branch_id
      and attendance_date = new.overtime_date;

    if not found then
      raise exception 'Attendance record not found for employee % on %',
        new.employee_id, new.overtime_date;
    end if;
  elsif new.status = 'rejected' then
    update public.attendance
    set ot_requested = false,
        ot_authorized = false,
        approved_ot_minutes = null
    where employee_id = new.employee_id
      and branch_id = new.branch_id
      and attendance_date = new.overtime_date;
  end if;
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.approve_employee_request_internal(request_id uuid, new_employee_id text)
 RETURNS employees
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
declare
  request_row public.employee_requests;
  created_employee public.employees;
  clean_employee_id text := upper(trim(new_employee_id));
begin
  if clean_employee_id = '' then
    raise exception 'Employee ID is required.';
  end if;

  select * into request_row
  from public.employee_requests
  where id = request_id
  for update;

  if not found then
    raise exception 'Employee request was not found.';
  end if;

  if request_row.status <> 'PENDING' then
    raise exception 'Employee request has already been reviewed.';
  end if;

  insert into public.employees (
    employee_id, name, designation, department, email, new_ic_no,
    bank_code, bank_account, phone, address, joining_date,
    is_active, branch_id
  ) values (
    clean_employee_id, request_row.name, request_row.designation,
    request_row.department, request_row.email, request_row.new_ic_no,
    request_row.bank_code, request_row.bank_account, request_row.phone,
    request_row.address, request_row.joining_date, true,
    request_row.branch_id
  ) returning * into created_employee;

  update public.employee_requests
  set status = 'APPROVED',
      assigned_employee_id = clean_employee_id,
      reviewed_at = now()
  where id = request_id;

  return created_employee;
end;
$function$
;

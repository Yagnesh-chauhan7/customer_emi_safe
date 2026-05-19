-- Add fcm_token and is_settled to customer_table


-- Create customer_service_table
create table if not exists public.customer_service_table (
  service_id uuid not null default extensions.uuid_generate_v4 (),
  owner_id uuid null,
  customer_id uuid null,
  service_wifi boolean null default false,
  service_internet boolean null default false,
  service_bluetooth boolean null default false,
  service_location boolean null default false,
  location_lat character varying null,
  location_long character varying null,
  service_lock boolean null default false,
  service_app_hide boolean null default false,
  service_wallpaper boolean null default false,
  allow_factory_reset boolean null default false,
  app_uninstall boolean null default false,
  emi_done boolean null default false,
  sim_number1 character varying null,
  sim_number2 character varying null,
  sim_provider1 character varying null,
  sim_provider2 character varying null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone null,
  constraint customer_service_table_pkey primary key (service_id),
  constraint customer_service_table_customer_id_fkey foreign KEY (customer_id) references customer_table (customer_id),
  constraint customer_service_table_owner_id_fkey foreign KEY (owner_id) references shop_owner_table (owner_id)
) TABLESPACE pg_default;

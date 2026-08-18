-- Remove the first three accounts from the Scrolla preferred-user program.
-- This strips only the complimentary Scrolla grant shape: Gold plan with the
-- far-future manual expiration used by the registry. Purchased subscriptions
-- with normal expiration dates are intentionally left alone.

update public.users
set
  is_verified = false,
  subscription_plan = null,
  subscription_expires_at = null,
  updated_at = now()
where id in (
  'b3d229af-a92c-44eb-8d12-f4835cf8218d'::uuid, -- jackson.kershner.music
  'f75e31c0-9360-4484-aa06-39e7001cdb31'::uuid, -- gabe.nickel.music
  '81e178bd-ae21-4fce-b25d-d2869c4edc41'::uuid  -- eaton.gav
)
and is_founder = false
and subscription_plan = 'scrolls.gold.monthly'
and subscription_expires_at >= '2099-01-01T00:00:00Z'::timestamptz;

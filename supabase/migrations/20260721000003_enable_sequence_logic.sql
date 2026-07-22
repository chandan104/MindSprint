-- Sequence Logic gameplay ships in this release (completes the core six):
-- enable its rollout flag.
update public.feature_flags
   set enabled = true
 where key = 'sequence_logic_module';

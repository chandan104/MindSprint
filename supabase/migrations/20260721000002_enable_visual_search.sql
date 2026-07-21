-- Visual Search gameplay ships in this release: enable its rollout flag.
update public.feature_flags
   set enabled = true
 where key = 'visual_search_module';

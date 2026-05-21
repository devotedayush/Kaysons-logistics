update public.ai_prompt_templates
set template_text = 'Review e-way bill and GR risk for {{start_date}} to {{end_date}}. Focus on duplicate e-way bills, missing e-way/GR, mismatch between invoice and delivery proof, delayed dispatch after bill date, and missing POD/acknowledgement. If the date variables are blank, use the latest computed facts. Explain business impact, payment risk, compliance risk, and exact next checks for admin/accountant. Do not accuse fraud as fact unless evidence is conclusive.',
    variables_schema = '{"start_date":"YYYY-MM-DD optional","end_date":"YYYY-MM-DD optional"}'::jsonb,
    updated_at = now()
where name = 'E-way bill fraud review';

update public.ai_prompt_templates
set template_text = 'Review route cost spike for {{route_key}} during {{start_date}} to {{end_date}}. Compare current freight, extra charges, total freight, PMT, and transporter behavior against the backend baseline. Identify whether the spike is from base freight, detention, toll tax, point charge, out-route, deduction reversal, vehicle type, weight, or repeated transporter pattern. If route_key is blank, list the riskiest routes first.',
    variables_schema = '{"route_key":"optional route label","start_date":"YYYY-MM-DD optional","end_date":"YYYY-MM-DD optional"}'::jsonb,
    updated_at = now()
where name = 'Route cost spike review';

update public.ai_prompt_templates
set template_text = 'Review transporter {{transporter_name}} for cost, delay, proof quality, acknowledgement pending, e-way/GR mismatch, duplicate e-way, and unusual extra-charge patterns. Compare against other transporters and this transporter''s recent baseline when available. If transporter_name is blank, rank the transporters needing review first. Recommend whether to continue normally, verify documents, hold payment, or escalate to admin review.',
    variables_schema = '{"transporter_name":"optional transporter name"}'::jsonb,
    updated_at = now()
where name = 'Transporter performance review';

insert into public.ai_prompt_templates (name, category, template_text, variables_schema)
values
  (
    'Pending POD and acknowledgement review',
    'proof_acknowledgement',
    'Find deliveries where POD, GR, e-way bill, receiver details, or acknowledgement are missing or delayed. Prioritize cases where freight is completed/dispatched but acknowledgement is still pending, or where proof arrived late. Explain payment risk, customer dispute risk, and who should follow up.',
    '{"start_date":"YYYY-MM-DD optional","end_date":"YYYY-MM-DD optional"}'::jsonb
  ),
  (
    'Extra charges and deductions audit',
    'charge_audit',
    'Audit extra freight, labour, detention, toll tax, point charge, out-route, other charges, and deductions. Highlight loads where extra charges are unusually high versus base freight or route baseline. Explain which charge type caused the increase and what document/proof should be checked before payment.',
    '{"start_date":"YYYY-MM-DD optional","transporter_name":"optional transporter name","route_key":"optional route label"}'::jsonb
  ),
  (
    'Payment hold risk review',
    'payment_control',
    'List freight records that should be reviewed before payment release because of duplicate e-way bill, missing proof, delayed acknowledgement, high extra charges, route cost spike, or transporter compliance gaps. Give a short payment-control action for each risk category.',
    '{"start_date":"YYYY-MM-DD optional","end_date":"YYYY-MM-DD optional"}'::jsonb
  )
on conflict do nothing;

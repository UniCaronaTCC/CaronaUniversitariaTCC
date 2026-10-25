// A mesma janela e usada no encerramento automatico e na troca de veiculo.
export const CARONA_VENCIDA_SQL = `
  (
    ((recorrente = false OR id_recorrencia IS NULL)
      AND (data_inicio + horario + INTERVAL '2 hours') <=
        (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo'))
    OR
    (recorrente = true AND data_fim IS NOT NULL
      AND (data_fim + horario) <=
        (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo'))
  )
`;

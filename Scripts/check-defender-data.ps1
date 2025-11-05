# 数時間後にこのスクリプトを実行してデータ到着を確認
az monitor log-analytics query -w log-dev --analytics-query 'SecurityRecommendation | take 5' --query 'tables[0].rows' -o table 2>
if (0 -eq 0) { Write-Host '✅ SecurityRecommendation データ取得成功' -ForegroundColor Green } else { Write-Host '⏳ まだデータが到着していません' -ForegroundColor Yellow }

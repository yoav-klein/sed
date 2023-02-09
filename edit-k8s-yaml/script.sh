
file=deployment.yaml
sed 's/^      containers:/      dnsConfig:\n        options:\n          - name: ndots\n            value: "4"\n      containers:/g;' $file > tmp1.yaml
#sed '/          dnsConfig:/{n;N;N;N;d};' tmp1.yaml > tmp2.yaml
#sed 's/          dnsConfig:/          containers:/g' tmp2.yaml > result.yaml



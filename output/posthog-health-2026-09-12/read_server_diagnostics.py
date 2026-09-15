import pathlib,re,json,datetime,collections,gzip
start=datetime.datetime.fromisoformat("2026-09-11T11:45:58+00:00")
end=datetime.datetime.fromisoformat("2026-09-12T11:45:58+00:00")
counts=collections.Counter(); hourly=collections.Counter(); failures=[]; coverage={}
for name in ["/var/log/nginx/access.log","/var/log/nginx/access.log-20260912"]:
 p=pathlib.Path(name)
 if not p.exists():continue
 seen=[]
 for line in p.open(errors="replace"):
  m=re.search(r'\[([^\]]+)\] "([A-Z]+) ([^ ]+) [^"]+" (\d+) \d+ "[^"]*" "([^"]*)"',line)
  if not m:continue
  try:t=datetime.datetime.strptime(m[1],"%d/%b/%Y:%H:%M:%S %z")
  except:continue
  seen.append(t)
  if not(start<=t<end):continue
  path=m[3].split("?")[0]
  if path!="/ai/gemini":continue
  agent="ios" if ("CFNetwork" in m[5] or "Darwin" in m[5]) else "android" if "okhttp" in m[5].lower() else "other"
  counts[(agent,m[4])]+=1
  hourly[(t.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:00Z"),agent,m[4])]+=1
  if int(m[4])>=400:failures.append({"utc":t.astimezone(datetime.timezone.utc).isoformat(),"platform":agent,"status":int(m[4])})
 if seen:coverage[p.name]=[min(seen).isoformat(),max(seen).isoformat()]
print(json.dumps({"accessCoverage":coverage,"aiGeminiCounts":[{"platform":a,"status":s,"n":n} for (a,s),n in counts.items()],"aiGeminiFailures":failures,"hourly":[{"hour":h,"platform":a,"status":s,"n":n} for (h,a,s),n in sorted(hourly.items())]},ensure_ascii=False))
p=pathlib.Path("/root/.pm2/logs/chillnote-error-0.log")
lines=p.read_text(errors="replace").splitlines()
markers=[]
for i,line in enumerate(lines):
 if "Gemini API Error:" not in line and "Gemini Error:" not in line:continue
 block="\n".join(lines[i:i+40])
 stamp=re.search(r'20\d\d-\d\d-\d\d[T ][0-9:.+Z-]+',line)
 record={"timePrefix":stamp[0] if stamp else None}
 for label,pat in {"status":r"status: (\d{3})","model":r"model: ['\"]([a-zA-Z0-9.-]+)","usageType":r"usageType: ['\"]([a-zA-Z0-9_-]+)","hasAudio":r"hasAudio: (true|false)","hasImage":r"hasImage: (true|false)"}.items():
  match=re.search(pat,block)
  if match:record[label]=match[1]
 record["categories"]=[c for c in ["RESOURCE_EXHAUSTED","UNAVAILABLE","PERMISSION_DENIED","INVALID_ARGUMENT","DEADLINE_EXCEEDED","fetch failed","ECONNRESET","UND_ERR_CONNECT_TIMEOUT","quota","rate limit"] if c in block]
 markers.append(record)
print(json.dumps({"appErrorMarkersTotal":len(markers),"last30Markers":markers[-30:],"timestampedLines":sum(bool(re.search(r"20\d\d-\d\d-\d\d",l[:60])) for l in lines),"totalLines":len(lines)},ensure_ascii=False))


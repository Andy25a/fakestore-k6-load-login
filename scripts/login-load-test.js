import http from 'k6/http';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';
import { parse } from 'https://jslib.k6.io/papaparse/5.1.1/index.js';
import { htmlReport } from 'https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.1/index.js';

const users = new SharedArray('users csv', function () {
  const csvData = open('../data/users.csv');
  return parse(csvData, { header: true, skipEmptyLines: true }).data;
});

export const options = {
  scenarios: {
    login_load: {
      executor: 'constant-arrival-rate',
      rate: 21,
      timeUnit: '1s',
      duration: '1m',
      preAllocatedVUs: 30,
      maxVUs: 100,
    },
  },
  thresholds: {
    http_req_duration: ['max<=1500'],
    http_req_failed: ['rate<0.03'],
    http_reqs: ['rate>=20'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'max'],
};

const BASE_URL = 'https://fakestoreapi.com';
const MAX_RESP_MS = 1500;

function formatTimestamp(d) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

export function handleSummary(data) {
  const ts = __ENV.REPORT_TIMESTAMP || formatTimestamp(new Date());
  const summaryFile = __ENV.REPORT_SUMMARY_FILE || `reports/summaries/k6-summary-${ts}.json`;
  const htmlFile = __ENV.REPORT_HTML_FILE || `reports/html/k6-report-${ts}.html`;
  return {
    [htmlFile]: htmlReport(data),
    [summaryFile]: JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

export default function () {
  const row = users[__ITER % users.length];
  const username = row.user || row.username || row['\ufeffuser'];
  const password = row.passwd || row.password || row['\ufeffpasswd'];
  if (!username || !password) {
    return;
  }
  const payload = JSON.stringify({
    username: username,
    password: password,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '60s',
  };

  const res = http.post(`${BASE_URL}/auth/login`, payload, params);

  const isAcceptedStatus = res.status > 0 && res.status < 500;

  check(res, {
    'status HTTP menor a 500': () => isAcceptedStatus,
    [`tiempo de respuesta <= ${MAX_RESP_MS} ms`]: () => res.timings.duration <= MAX_RESP_MS,
  });

  sleep(0.05);
}

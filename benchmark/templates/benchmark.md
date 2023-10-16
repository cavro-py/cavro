---
custom_edit_url: null
---
import { Line } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  Colors,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js';
ChartJS.register(
  CategoryScale,
  Colors,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
);

# Benchmarks

These benchmarks are non-scientific, and are measured in uncontrolled environments. 

Their goal is to ensure that the performance of `cavro` is adequate compared to other offerings,
and to highlight any performance regressions early.

Each test is run 3 times for each library under test, and the results collected.  Graphs show the fastest run time.


### Most Recent Run

 * Commit Hash: `{{ latest_result.hash }}`
 * Run time: `{{latest_result.date}}`

{% for test in tests %}
### {{test}}
{% with test_cls = classes[test] %}

{% if test_cls.__doc__ %}
:::info
{{ dedent(test_cls.__doc__) }}
:::
{% endif %}
#### History
<Line data={{ line_data(results, test) }} options={{ '{{' }}
    scales: {
        x: {title:{display: true, text: "Commit Hash"}},
        y: {title:{display: true, text: "Time Taken (s) Lower is better"}},
    },
    interaction: { mode: 'x' },
    animation: {duration: 0}
}}/>

#### Last Run Results
{{ results_table(results, test) }}

{% endwith %}


{% endfor %}
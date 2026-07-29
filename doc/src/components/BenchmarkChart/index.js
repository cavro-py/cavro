import React, {useState} from 'react';
import {Line} from 'react-chartjs-2';
import {
  Chart as ChartJS,
  Colors,
  CategoryScale,
  LinearScale,
  LogarithmicScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js';
import styles from './styles.module.css';

ChartJS.register(
  CategoryScale,
  Colors,
  LinearScale,
  LogarithmicScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
);

export default function BenchmarkChart({
  data,
  xTitle = 'Commit Hash',
  yTitle = 'Time Taken (s) Lower is better',
}) {
  const [logScale, setLogScale] = useState(false);

  const options = {
    scales: {
      x: {title: {display: true, text: xTitle}},
      y: {
        type: logScale ? 'logarithmic' : 'linear',
        title: {display: true, text: yTitle},
      },
    },
    interaction: {mode: 'x'},
    animation: {duration: 0},
  };

  return (
    <div className={styles.chart}>
      <Line data={data} options={options} />
      <label className={styles.toggle}>
        <input
          type="checkbox"
          checked={logScale}
          onChange={(event) => setLogScale(event.target.checked)}
        />
        Logarithmic scale
      </label>
    </div>
  );
}

import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

const FeatureList = [
  {
    title: 'High Performance',
    img: require('@site/static/img/racecar.png').default,
    description: (
      <>
        cavro is faster than other python avro libraries. Schemas are parsed into
        class structures internally, minimizing expensive dict lookups.
      </>
    ),
  },
  {
    title: 'Easy to Use',
    img: require('@site/static/img/simple.png').default,
    description: (
      <>
        cavro is designed with a pythonic interface, that makes reading and writing all forms of AVRO simple.
      </>
    ),
  },
  {
    title: 'Cython extension',
    Svg: require('@site/static/img/cython.svg').default,
    description: (
      <>
        cavro is implemented as a cython extension, so it's fast, and easy to install, without sacrificing readability.
      </>
    ),
  },
];

function Feature({Svg, title, description, img}) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        { Svg ? <Svg className={styles.featureSvg} role="img" /> : <img src={img} className={styles.featureSvg} role="img" /> }
      </div>
      <div className="text--center padding-horiz--md">
        <h3>{title}</h3>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}

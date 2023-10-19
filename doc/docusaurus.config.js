// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const lightCodeTheme = require('prism-react-renderer/themes/github');
const darkCodeTheme = require('prism-react-renderer/themes/dracula');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'cavro',
  tagline: 'A fast python avro library',
  favicon: 'img/favicon.ico',

  url: 'https://cavro.io',
  baseUrl: '/',

  organizationName: 'cavro-py',
  projectName: 'cavro',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  markdown: {
    mermaid: true
  },

  themes: [
    '@easyops-cn/docusaurus-search-local',
    '@docusaurus/theme-mermaid',
  ],

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl:
            'https://github.com/cavro-py/cavro/tree/main/doc/',
        },
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/logo-64.png',
      navbar: {
        title: 'cavro',
        logo: {
          alt: 'cavro logo',
          src: 'img/logo-64.png',
        },
        items: [
          {
            href: '/docs/user-guide/intro',
            position: 'left',
            label: 'User Guide',
          },
          {
            href: '/docs/API',
            position: 'left',
            label: 'API Reference',
          },
          {
            href: 'https://github.com/cavro-py/cavro',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              {
                label: 'Quick Intro',
                to: '/docs/user-guide/intro',
              },
            ],
          },
          {
            title: 'Other Links',
            items: [
              {
                label: 'Avro site',
                href: 'https://avro.apache.org/',
              },
              {
                label: 'Official Avro Python',
                href: 'https://avro.apache.org/docs/1.11.1/getting-started-python/',
              },
              {
                label: 'Fastavro',
                href: 'https://github.com/fastavro/fastavro',
              },
            ],
          },
          {
            title: 'More',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/cavro-py/cavro',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Offset Design Ltd. Built with Docusaurus.`,
      },
      prism: {
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
      },
    }),
};

module.exports = config;

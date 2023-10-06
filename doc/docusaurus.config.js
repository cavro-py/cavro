// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const lightCodeTheme = require('prism-react-renderer/themes/github');
const darkCodeTheme = require('prism-react-renderer/themes/dracula');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'cavro',
  tagline: 'A fast python avro library',
  favicon: 'img/favicon.ico',

  // Set the production url of your site here
  url: 'https://cavro.io',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'stestagg', // Usually your GitHub org/user name.
  projectName: 'cavro', // Usually your repo name.

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  // Even if you don't use internalization, you can use this field to set useful
  // metadata like html lang. For example, if your site is Chinese, you may want
  // to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/stestagg/cavro/tree/main/doc/',
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
      // Replace with your project's social card
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
            href: 'https://github.com/stestagg/cavro',
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
                href: 'https://github.com/stestagg/cavro',
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

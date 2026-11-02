import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Codexis',
  description: 'Engineering field guide for Codexis, an Android-first local source-code intelligence prototype.',
  cleanUrls: true,
  lastUpdated: true,
  themeConfig: {
    logo: '/codexis-mark.svg',
    siteTitle: 'Codexis / Field guide',
    nav: [
      { text: 'Overview', link: '/' },
      { text: 'Architecture', link: '/architecture' },
      { text: 'Development', link: '/workflow' },
      { text: 'Status', link: '/status' },
    ],
    sidebar: [
      {
        text: 'Start here',
        items: [
          { text: 'Project overview', link: '/' },
          { text: 'Implementation status', link: '/status' },
        ],
      },
      {
        text: 'System design',
        items: [
          { text: 'Architecture', link: '/architecture' },
          { text: 'Android runtime', link: '/android-runtime' },
        ],
      },
      {
        text: 'Build & contribute',
        items: [
          { text: 'Environment and setup', link: '/setup' },
          { text: 'Development workflow', link: '/workflow' },
          { text: 'Checks and experiments', link: '/testing' },
        ],
      },
    ],
    outline: { level: [2, 3], label: 'On this page' },
    search: { provider: 'local' },
    footer: {
      message: 'Local first. Read only. Evidence led.',
      copyright: 'Codexis engineering documentation',
    },
    socialLinks: [],
  },
})

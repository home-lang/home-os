import type { BunPressConfig } from 'bunpress'

export default {
  title: 'HomeOS',
  description: 'A feature-complete, production-grade operating system with 210+ kernel modules built from scratch using the Home Programming Language',
  lang: 'en-US',
  base: '/os/',

  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/os/logo.svg' }],
    ['meta', { name: 'theme-color', content: '#5c6bc0' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'HomeOS Documentation' }],
    ['meta', { property: 'og:description', content: 'A modern operating system for x86-64 and ARM64 architectures, with first-class Raspberry Pi 5 support' }],
    ['meta', { property: 'og:url', content: 'https://home-language.org/os/' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:title', content: 'HomeOS Documentation' }],
    ['meta', { name: 'twitter:description', content: 'A modern operating system for x86-64 and ARM64 architectures' }],
  ],

  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'HomeOS',

    nav: [
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'API', link: '/api/syscalls' },
      {
        text: 'Related',
        items: [
          { text: 'Home Language', link: 'https://home-language.org/home/' },
          { text: 'Pantry', link: 'https://home-language.org/pantry/' },
          { text: 'Den', link: 'https://home-language.org/den/' },
          { text: 'Craft', link: 'https://home-language.org/craft/' },
        ],
      },
      {
        text: 'Links',
        items: [
          { text: 'GitHub', link: 'https://github.com/home-language/os' },
          { text: 'Changelog', link: 'https://github.com/home-language/os/blob/main/CHANGELOG.md' },
          { text: 'Contributing', link: 'https://github.com/home-language/os/blob/main/CONTRIBUTING.md' },
        ],
      },
    ],

    sidebar: {
      '/': [
        {
          text: 'Introduction',
          items: [
            { text: 'What is HomeOS?', link: '/' },
            { text: 'Getting Started', link: '/guide/getting-started' },
          ],
        },
        {
          text: 'Core Concepts',
          items: [
            { text: 'Architecture', link: '/guide/architecture' },
            { text: 'File Systems', link: '/guide/filesystems' },
            { text: 'Networking', link: '/guide/networking' },
            { text: 'Device Drivers', link: '/guide/drivers' },
          ],
        },
        {
          text: 'Features',
          items: [
            { text: 'Process Management', link: '/features/processes' },
            { text: 'Memory Management', link: '/features/memory' },
            { text: 'File Systems', link: '/features/filesystems' },
            { text: 'Networking Stack', link: '/features/networking' },
            { text: 'Device Drivers', link: '/features/drivers' },
            { text: 'Security Model', link: '/features/security' },
          ],
        },
        {
          text: 'Platform Guides',
          items: [
            { text: 'Raspberry Pi 5', link: '/guide/rpi5' },
          ],
        },
        {
          text: 'Development',
          items: [
            { text: 'Applications', link: '/guide/apps' },
          ],
        },
        {
          text: 'Advanced',
          items: [
            { text: 'Kernel Modules', link: '/advanced/kernel-modules' },
            { text: 'Custom Drivers', link: '/advanced/custom-drivers' },
            { text: 'Performance Tuning', link: '/advanced/performance' },
            { text: 'Debugging Kernel', link: '/advanced/debugging' },
            { text: 'Multi-Architecture', link: '/advanced/multi-arch' },
          ],
        },
        {
          text: 'API Reference',
          items: [
            { text: 'System Calls', link: '/api/syscalls' },
            { text: 'Driver API', link: '/api/drivers' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/home-language/os' },
      { icon: 'discord', link: 'https://discord.gg/home-language' },
    ],

    editLink: {
      pattern: 'https://github.com/home-language/os/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright 2024-present HomeOS Contributors',
    },

    search: {
      provider: 'local',
    },

    lastUpdated: {
      text: 'Last updated',
      formatOptions: {
        dateStyle: 'medium',
        timeStyle: 'short',
      },
    },
  },
} satisfies BunPressConfig

import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    'intro',
    'configuration',
    'prd-format',
    'skills',
    'workflows',
    'notifications',
    'live-updates',
    'mcp-tools',
    'session-isolation',
    {
      type: 'category',
      label: 'Advanced',
      items: [
        'advanced/skill-creation-guide',
        'advanced/claude-md-layering',
      ],
    },
  ],
};

export default sidebars;

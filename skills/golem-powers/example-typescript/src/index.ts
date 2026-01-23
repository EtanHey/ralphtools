// index.ts - Example TypeScript skill demonstrating Pattern B
// Usage: bun run src/index.ts --action=default|random|env

// Parse command line arguments
const args = process.argv.slice(2);

function getArg(name: string, defaultValue: string = ""): string {
  const arg = args.find((a) => a.startsWith(`--${name}=`));
  return arg?.split("=")[1] || defaultValue;
}

const action = getArg("action", "default");

// Type definitions demonstrating TypeScript benefits
interface SkillResult {
  action: string;
  timestamp: string;
  data: Record<string, unknown>;
}

// Helper to format Markdown output
function printMarkdown(result: SkillResult): void {
  console.log("## Example TypeScript Skill");
  console.log("");
  console.log(`**Action:** \`${result.action}\``);
  console.log(`**Timestamp:** ${result.timestamp}`);
  console.log("");

  if (Object.keys(result.data).length > 0) {
    console.log("### Result");
    console.log("");
    console.log("```json");
    console.log(JSON.stringify(result.data, null, 2));
    console.log("```");
  }
}

// Action handlers
async function handleDefault(): Promise<SkillResult> {
  return {
    action: "default",
    timestamp: new Date().toISOString(),
    data: {
      message: "This skill executed successfully!",
      runtime: "Bun",
      bunVersion: Bun.version,
      features: ["Type safety", "Async support", "Structured data", "npm ecosystem"],
      howItWorks: [
        "You invoked /golem-powers:example-typescript",
        "Claude loaded SKILL.md and saw execute: scripts/run.sh --action=default",
        "scripts/run.sh executed: bun run src/index.ts --action=default",
        "This TypeScript code ran and returned Markdown",
      ],
    },
  };
}

async function handleRandom(): Promise<SkillResult> {
  // Demonstrate TypeScript's type safety and data processing
  const items = ["apple", "banana", "cherry", "date", "elderberry"];
  const randomIndex = Math.floor(Math.random() * items.length);
  const randomNumber = Math.random();

  return {
    action: "random",
    timestamp: new Date().toISOString(),
    data: {
      randomItem: items[randomIndex],
      randomNumber: randomNumber.toFixed(4),
      uuid: crypto.randomUUID(),
      dice: Math.floor(Math.random() * 6) + 1,
    },
  };
}

async function handleEnv(): Promise<SkillResult> {
  return {
    action: "env",
    timestamp: new Date().toISOString(),
    data: {
      cwd: process.cwd(),
      platform: process.platform,
      arch: process.arch,
      nodeVersion: process.version,
      bunVersion: Bun.version,
      args: args,
    },
  };
}

// Main execution
async function main(): Promise<void> {
  let result: SkillResult;

  switch (action) {
    case "default":
      result = await handleDefault();
      break;
    case "random":
      result = await handleRandom();
      break;
    case "env":
      result = await handleEnv();
      break;
    default:
      console.error(`Unknown action: ${action}`);
      console.error("Available actions: default, random, env");
      process.exit(1);
  }

  printMarkdown(result);

  // Additional info for default action
  if (action === "default") {
    console.log("");
    console.log("### Pattern B: TypeScript");
    console.log("");
    console.log("This pattern is ideal for:");
    console.log("");
    console.log("- Complex business logic");
    console.log("- API integrations");
    console.log("- Type-safe data processing");
    console.log("- Async operations");
    console.log("");
    console.log("To create your own: `/golem-powers:writing-skills`");
  }
}

main().catch((error) => {
  console.error("Error:", error.message);
  process.exit(1);
});

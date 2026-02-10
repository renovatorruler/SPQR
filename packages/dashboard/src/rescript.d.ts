// Allow TypeScript to import compiled ReScript modules
declare module "*.res.mjs" {
  const component: React.ComponentType<any>
  export default component
  export const make: React.ComponentType<any>
}

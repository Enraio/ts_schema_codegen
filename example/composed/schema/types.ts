// Shared type declarations for the composed schema.

export interface FieldDef {
  id: string;
  type: 'string' | 'array' | 'text';
  label: string;
  options?: string[];
  required?: boolean;
  hint?: string;
  defaultValue?: string;
}

export interface FieldSet {
  label: string;
  categories: string[];
  subcategoryRoutes?: string[];
  fields: FieldDef[];
}

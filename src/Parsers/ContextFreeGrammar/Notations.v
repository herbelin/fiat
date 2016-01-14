Require Import Coq.Strings.String Coq.Strings.Ascii Coq.Lists.List.
Require Import Fiat.Parsers.ContextFreeGrammar.Core.
Require Import Fiat.Common.List.Operations.
Require Import Fiat.Common.Equality.
Require Export Fiat.Parsers.ContextFreeGrammar.PreNotations.

Export Coq.Strings.Ascii.
Export Coq.Strings.String.
Export Fiat.Parsers.ContextFreeGrammar.Core.

Delimit Scope item_scope with item.
Bind Scope item_scope with item.
Delimit Scope production_scope with production.
Delimit Scope production_assignment_scope with prod_assignment.
Bind Scope production_scope with production.
Delimit Scope productions_scope with productions.
Delimit Scope productions_assignment_scope with prods_assignment.
Bind Scope productions_scope with productions.
Delimit Scope grammar_scope with grammar.
Bind Scope grammar_scope with grammar.

(** single characters are terminals, everything else is a nonterminal *)
Coercion production_of_string (s : string) : production Ascii.ascii
  := match s with
       | EmptyString => nil
       | String.String ch EmptyString => (Terminal (ascii_beq ch))::nil
       | _ => (NonTerminal s)::nil
     end.

Global Arguments production_of_string / .

(** juxtaposition of productions should yield concatenation *)
Definition magic_juxta_append_production {T} (p ps : production T) : production T
  := Eval compute in p ++ ps.
Coercion magic_juxta_append_production : production >-> Funclass.

Coercion productions_of_production {T} (p : production T) : productions T
  := p::nil.

Definition magic_juxta_append_productions {T} (p ps : productions T) : productions T
  := Eval compute in p ++ ps.

Notation "p || p'" := (magic_juxta_append_productions (p%productions)(p'%productions)) : productions_scope.

Global Arguments production_of_string / .
Global Arguments magic_juxta_append_production / .
Global Arguments productions_of_production / .
Global Arguments magic_juxta_append_productions / .

Notation "n0 ::== r0" := ((n0 : string)%string, (r0 : productions _)%productions) (at level 100) : production_assignment_scope.
Notation "[[[ x ;; .. ;; y ]]]" :=
  (list_to_productions nil (cons x%prod_assignment .. (cons y%prod_assignment nil) .. )) : productions_assignment_scope.
Notation "[[[ x ;; .. ;; y ]]]" :=
  (list_to_grammar nil (cons x%prod_assignment .. (cons y%prod_assignment nil) .. )) : grammar_scope.

Local Open Scope string_scope.
Global Open Scope grammar_scope.
Global Open Scope string_scope.

Notation code_le ch ch' := (Compare_dec.leb (nat_of_ascii ch) (nat_of_ascii ch')).
Notation code_in_range ch ch_low ch_high := (code_le ch_low ch && code_le ch ch_high)%bool.

Notation "'[0-9]'" := (Terminal (fun ch => code_in_range ch "0" "9")) : item_scope.
Notation "'[0-9]'" := (([0-9]%item::nil) : production _) : production_scope.
Notation "'[0-9]'" := ([0-9]%production) : productions_scope.
Notation "'[A-Z]'" := (Terminal (fun ch => code_in_range ch "A" "Z")) : item_scope.
Notation "'[A-Z]'" := (([A-Z]%item::nil) : production _) : production_scope.
Notation "'[A-Z]'" := ([A-Z]%production) : productions_scope.
Notation "'[a-z]'" := (Terminal (fun ch => code_in_range ch "a" "z")) : item_scope.
Notation "'[a-z]'" := (([a-z]%item::nil) : production _) : production_scope.
Notation "'[a-z]'" := ([a-z]%production) : productions_scope.

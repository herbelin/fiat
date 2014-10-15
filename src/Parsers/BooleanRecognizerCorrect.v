(** * Definition of a boolean-returning CFG parser-recognizer *)
Require Import Coq.Lists.List Coq.Program.Program Coq.Program.Wf Coq.Arith.Wf_nat Coq.Arith.Compare_dec Coq.Classes.RelationClasses Coq.Strings.String.
Require Import Parsers.ContextFreeGrammar Parsers.Specification Parsers.BooleanRecognizer.
Require Import Common Common.ilist.
Require Import Eqdep_dec.

Local Hint Extern 0 =>
match goal with
  | [ H : false = true |- _ ] => solve [ destruct (Bool.diff_false_true H) ]
  | [ H : true = false |- _ ] => solve [ destruct (Bool.diff_true_false H) ]
end.

Coercion is_true (b : bool) := b = true.

Local Open Scope string_like_scope.

Section sound.
  Section general.
    Context CharType (String : string_like CharType) (G : grammar CharType).
    Context (productions_listT : Type)
            (initial_productions_data : productions_listT)
            (is_valid_productions : productions_listT -> productions CharType -> bool)
            (remove_productions : productions_listT -> productions CharType -> productions_listT)
            (productions_listT_R : productions_listT -> productions_listT -> Prop)
            (remove_productions_dec : forall ls prods, is_valid_productions ls prods = true
                                                       -> productions_listT_R (remove_productions ls prods) ls)
            (ntl_wf : well_founded productions_listT_R)
            (split_string_for_production
             : forall (str0 : String) (prod : production CharType), list (String * String))
            (split_string_for_production_correct
             : forall str0 prod,
                 List.Forall (fun s1s2 => fst s1s2 ++ snd s1s2 =s str0)
                             (split_string_for_production str0 prod)).

    Section parts.
      Local Hint Constructors parse_of_item parse_of parse_of_production.

      Section item.
        Context (str : String)
                (str_matches_productions : productions CharType -> bool).

        Definition str_matches_productions_soundT
          := forall prods, str_matches_productions prods = true
                           -> parse_of _ G str prods.

        Definition str_matches_productions_completeT
          := forall prods, parse_of _ G str prods
                           -> str_matches_productions prods = true.

        Lemma parse_item_sound
              (str_matches_productions_sound : str_matches_productions_soundT)
              (it : item CharType)
        : parse_item String G str str_matches_productions it = true -> parse_of_item _ G str it.
        Proof.
          unfold parse_item, str_matches_productions_soundT in *.
          repeat match goal with
                   | _ => intro
                   | [ H : context[match ?E with _ => _ end] |- _ ] => atomic E; destruct E
                   | [ |- context[match ?E with _ => _ end] ] => atomic E; destruct E
                   | [ H : _ = true |- _ ] => apply bool_eq_correct in H
                   | _ => progress subst
                   | _ => solve [ eauto ]
                 end.
        Defined.

        Lemma parse_item_complete
              (str_matches_productions_complete : str_matches_productions_completeT)
              (it : item CharType)
        : parse_of_item _ G str it -> parse_item String G str str_matches_productions it = true.
        Proof.
          unfold parse_item, str_matches_productions_completeT in *.
          repeat match goal with
                   | _ => intro
                   | _ => reflexivity
                   | [ H : parse_of_item _ _ ?s ?i |- _ ] => atomic s; atomic i; destruct H
                   | [ |- _ = true ] => apply bool_eq_correct
                   | _ => solve [ eauto ]
               end.
        Qed.
      End item.

      Section production.
        Context (str0 : String)
                (parse_productions : forall (str : String),
                                       str ≤s str0
                                       -> productions CharType
                                       -> bool).

        Definition parse_productions_soundT
          := forall str pf prods,
               @parse_productions str pf prods = true
               -> parse_of _ G str prods.

        Definition parse_productions_completeT
          := forall str pf prods,
               parse_of _ G str prods
               -> @parse_productions str pf prods = true.

        Definition split_correctT
                   (str1 : String)
                   (split : String * String)
          := fst split ++ snd split =s str1.

        Definition split_list_correctT str1 (split_list : list (String * String))
          := List.Forall (@split_correctT str1) split_list.

        Definition split_list_completeT
                   (str : String) (pf : str ≤s str0)
                   (split_list : list (String * String))
                   (prod : production CharType)
          := match prod return Type with
               | nil => True
               | it::its => ({ s1s2 : String * String
                                      & (fst s1s2 ++ snd s1s2 =s str)
                                        * (parse_of_item _ G (fst s1s2) it)
                                        * (parse_of_production _ G (snd s1s2) its) }%type)
                            -> ({ s1s2 : String * String
                                         & (In s1s2 split_list)
                                           * (parse_of_item _ G (fst s1s2) it)
                                           * (parse_of_production _ G (snd s1s2) its) }%type)
             end.

        Lemma parse_production_sound
                 (parse_productions_sound : parse_productions_soundT)
                 (str : String) (pf : str ≤s str0)
                 (prod : production CharType)
        : parse_production G split_string_for_production split_string_for_production_correct parse_productions pf prod = true
          -> parse_of_production _ G str prod.
        Proof.
          change (forall str0 prod, split_list_correctT str0 (split_string_for_production str0 prod)) in split_string_for_production_correct.
          revert str pf; induction prod;
          repeat match goal with
                   | _ => intro
                   | _ => progress simpl in *
                   | _ => progress subst
                   | _ => solve [ auto ]
                   | [ H : fold_right orb false (map _ _) = true |- _ ] => apply fold_right_orb_map_sig1 in H
                   | [ H : (_ || _)%bool = true |- _ ] => apply Bool.orb_true_elim in H
                   | [ H : (_ && _)%bool = true |- _ ] => apply Bool.andb_true_iff in H
                   | _ => progress destruct_head sumbool
                   | _ => progress destruct_head and
                   | _ => progress destruct_head sig
                   | _ => progress simpl in *
                   | _ => progress subst
                   | [ H : (_ =s _) = true |- _ ] => apply bool_eq_correct in H
                   | [ H : (_ =s _) = true |- _ ]
                     => let H' := fresh in
                        pose proof H as H';
                          apply bool_eq_correct in H';
                          progress subst
                 end.
          { constructor;
            solve [ eapply IHprod; eassumption
                  | eapply parse_item_sound; try eassumption;
                    hnf in parse_productions_sound |- *;
                    apply parse_productions_sound ]. }
        Defined.

        Lemma parse_production_complete
                 (parse_productions_complete : parse_productions_completeT)
                 (split_string_for_production_complete : forall str pf prod, @split_list_completeT str pf (split_string_for_production str prod) prod)
                 (str : String) (pf : str ≤s str0)
                 (prod : production CharType)
        : parse_of_production _ G str prod
          -> parse_production G split_string_for_production split_string_for_production_correct parse_productions pf prod = true.
        Proof.
          change (forall str0 prod, split_list_correctT str0 (split_string_for_production str0 prod)) in split_string_for_production_correct.
          revert str pf; induction prod;
          repeat match goal with
                   | _ => intro
                   | _ => progress simpl in *
                   | _ => progress subst
                   | _ => solve [ auto ]
                   | [ H : fold_right orb false (map _ _) = true |- _ ] => apply fold_right_orb_map_sig1 in H
                   | [ H : (_ || _)%bool = true |- _ ] => apply Bool.orb_true_elim in H
                   | [ H : (_ && _)%bool = true |- _ ] => apply Bool.andb_true_iff in H
                   | [ H : parse_of_production _ _ _ nil |- _ ] => inversion_clear H
                   | [ |- (_ =s _) = true ] => apply bool_eq_correct
                   | _ => progress destruct_head_hnf sumbool
                   | _ => progress destruct_head_hnf and
                   | _ => progress destruct_head_hnf sig
                   | _ => progress destruct_head_hnf sigT
                   | _ => progress destruct_head_hnf Datatypes.prod
                   | _ => progress simpl in *
                   | _ => progress subst
                   | [ H : (_ =s _) = true |- _ ] => apply bool_eq_correct in H
                   | [ H : (_ =s _) = true |- _ ]
                     => let H' := fresh in
                        pose proof H as H';
                          apply bool_eq_correct in H';
                          progress subst
                   | [ H : parse_of_production _ _ _ (_::_) |- _ ] => inversion H; clear H; subst
                   | [ H : ?s ≤s _ |- context[split_string_for_production_correct ?s ?p] ]
                     => specialize (fun a b p0 p1 p2
                                    => @split_string_for_production_complete s H p (existT _ (a, b) (p0, p1, p2)))
                   | [ H : forall a b, is_true (a ++ b =s _ ++ _) -> _ |- _ ]
                     => specialize (H _ _ (proj2 (@bool_eq_correct _ _ _ _) eq_refl))
                   | [ H : ?a -> ?b, H' : ?a |- _ ] => specialize (H H')
                   | [ |- fold_right orb false (map _ _) = true ] => apply fold_right_orb_map_sig2
                 end.
          match goal with
            | [ H : In (?s1, ?s2) (split_string_for_production ?str ?prod)
                |- { x : { s1s2 : _ | (fst s1s2 ++ snd s1s2 =s ?str) = true } | _ } ]
              => let H' := fresh in
                 pose proof (proj1 (@Forall_forall _ _ _) (@split_string_for_production_correct str prod) _ H) as H';
                   unfold split_correctT in H';
                   refine (exist _ (exist _ (s1, s2) _) _);
                   simpl in *
          end.
          repeat match goal with
                   | _ => split
                   | [ |- (_ && _)%bool = true ] => apply Bool.andb_true_iff
                   | _ => eapply parse_item_complete; try eassumption;
                          hnf in parse_productions_complete |- *;
                          solve [ apply parse_productions_complete ]
                   | _ => eapply IHprod; eassumption
                 end.
          apply In_combine_sig.
          Grab Existential Variables.
          assumption.
        Qed.
      End production.

      Section productions.
        Section step.
          Variable str0 : String.
          Variable parse_productions : forall (str : String)
                                              (pf : Length _ str < Length _ str0 \/ str = str0),
                                         productions CharType -> bool.

          (** To parse as a given list of [production]s, we must parse as one of the [production]s. *)
          Definition parse_productions_step (str : String) (pf : Length _ str < Length _ str0 \/ str = str0) (prods : productions CharType)
          : bool
            := fold_left orb
                         (map (parse_production parse_productions pf)
                              prods)
                         false.
        End step.

        Section wf.
          (** TODO: add comment explaining signature *)
          Definition parse_productions_or_abort_helper
          : forall (p : String * productions_listT) (str : String),
              Length String str < Length String (fst p) \/ str = fst p ->
              productions CharType -> bool
            := @Fix (prod String productions_listT)
                    _ (@well_founded_prod_relation
                         String
                         productions_listT
                         _
                         _
                         (well_founded_ltof _ (Length String))
                         ntl_wf)
                    _
                    (fun sl parse_productions str pf (prods : productions CharType)
                     => let str0 := fst sl in
                        let valid_list := snd sl in
                        match lt_dec (Length _ str) (Length _ str0) with
                          | left pf' =>
                            (** [str] got smaller, so we reset the valid productions list *)
                            parse_productions_step
                              (parse_productions
                                 (str, initial_productions_data)
                                 (or_introl pf'))
                              (or_intror eq_refl)
                              prods
                          | right pf' =>
                            (** [str] didn't get smaller, so we cache the fact that we've hit this productions already *)
                            (if is_valid_productions valid_list prods as is_valid
                                return is_valid_productions valid_list prods = is_valid -> _
                             then (** It was valid, so we can remove it *)
                               fun H' =>
                                 parse_productions_step
                                   (parse_productions
                                      (str0, remove_productions valid_list prods)
                                      (or_intror (conj eq_refl (remove_productions_dec H'))))
                                   (or_intror eq_refl)
                                   prods
                             else (** oops, we already saw this productions in the past.  ABORT! *)
                               fun _ => false
                            ) eq_refl
                        end).

          Definition parse_productions_or_abort (str0 str : String)
                     (valid_list : productions_listT)
                     (pf : Length _ str < Length _ str0 \/ str = str0)
                     (prods : productions CharType)
          : bool
            := parse_productions_or_abort_helper (str0, valid_list) pf prods.

          Definition parse_productions (str : String) (prods : productions CharType)
          : bool
            := @parse_productions_or_abort str str initial_productions_data
                                           (or_intror eq_refl) prods.
        End wf.

      End productions.
    End parts.
  End bool.
End recursive_descent_parser.

Section recursive_descent_parser_list.
  Context {CharType} {String : string_like CharType} {G : grammar CharType}.
  Variable (CharType_eq_dec : forall x y : CharType, {x = y} + {x <> y}).
  Definition rdp_list_productions_listT : Type := list (productions CharType).
  Definition rdp_list_is_valid_productions : rdp_list_productions_listT -> productions CharType -> bool
    := fun ls nt => if in_dec (productions_dec CharType_eq_dec) nt ls then true else false.
  Definition rdp_list_remove_productions : rdp_list_productions_listT -> productions CharType -> rdp_list_productions_listT
    := fun ls nt =>
         filter (fun x => if productions_dec CharType_eq_dec nt x then false else true) ls.
  Definition rdp_list_productions_listT_R : rdp_list_productions_listT -> rdp_list_productions_listT -> Prop
    := ltof _ (@List.length _).
  Lemma filter_list_dec {T} f (ls : list T) : List.length (filter f ls) <= List.length ls.
  Proof.
    induction ls; trivial; simpl in *.
    repeat match goal with
             | [ |- context[if ?a then _ else _] ] => destruct a; simpl in *
             | [ |- S _ <= S _ ] => solve [ apply Le.le_n_S; auto ]
             | [ |- _ <= S _ ] => solve [ apply le_S; auto ]
           end.
  Qed.
  Lemma rdp_list_remove_productions_dec : forall ls prods,
                                            @rdp_list_is_valid_productions ls prods = true
                                            -> @rdp_list_productions_listT_R (@rdp_list_remove_productions ls prods) ls.
  Proof.
    intros.
    unfold rdp_list_is_valid_productions, rdp_list_productions_listT_R, rdp_list_remove_productions, ltof in *.
    destruct (in_dec (productions_dec CharType_eq_dec) prods ls); [ | discriminate ].
    match goal with
      | [ H : In ?prods ?ls |- context[filter ?f ?ls] ]
        => assert (~In prods (filter f ls))
    end.
    { intro H'.
      apply filter_In in H'.
      destruct H' as [? H'].
      destruct (productions_dec CharType_eq_dec prods prods); congruence. }
    { match goal with
        | [ |- context[filter ?f ?ls] ] => generalize dependent f; intros
      end.
      induction ls; simpl in *; try congruence.
      repeat match goal with
               | [ |- context[if ?x then _ else _] ] => destruct x; simpl in *
               | [ H : _ \/ _ |- _ ] => destruct H
               | _ => progress subst
               | [ H : ~(_ \/ _) |- _ ] => apply Decidable.not_or in H
               | [ H : _ /\ _ |- _ ] => destruct H
               | [ H : ?x <> ?x |- _ ] => exfalso; apply (H eq_refl)
               | _ => apply Lt.lt_n_S
               | _ => apply Le.le_n_S
               | _ => apply filter_list_dec
               | [ H : _ -> _ -> ?G |- ?G ] => apply H; auto
             end. }
  Qed.
  Lemma rdp_list_ntl_wf : well_founded rdp_list_productions_listT_R.
  Proof.
    unfold rdp_list_productions_listT_R.
    intro.
    apply well_founded_ltof.
  Defined.
End recursive_descent_parser_list.

Section example_parse_string_grammar.
  Fixpoint make_all_single_splits (str : string) : list { strs : string * string | (fst strs ++ snd strs = str)%string }.
  Proof.
    refine ((exist _ (""%string, str) eq_refl)
              ::(match str with
                   | ""%string => nil
                   | String.String ch str' =>
                     map (fun p => exist _ (String.String ch (fst (proj1_sig p)),
                                            snd (proj1_sig p))
                                         _)
                         (make_all_single_splits str')
                 end)).
    clear.
    abstract (simpl; apply f_equal; apply proj2_sig).
  Defined.

  Lemma length_append (s1 s2 : string) : length (s1 ++ s2) = length s1 + length s2.
  Proof.
    revert s2.
    induction s1; simpl; trivial; [].
    intros.
    f_equal; auto.
  Qed.

  Fixpoint flatten1 {T} (ls : list (list T)) : list T
    := match ls with
         | nil => nil
         | x::xs => (x ++ flatten1 xs)%list
       end.

  Lemma flatten1_length_ne_0 {T} (ls : list (list T)) (H0 : Datatypes.length ls <> 0)
        (H1 : Datatypes.length (hd nil ls) <> 0)
  : Datatypes.length (flatten1 ls) <> 0.
  Proof.
    destruct ls as [| [|] ]; simpl in *; auto.
  Qed.

  Local Ltac t' :=
    match goal with
      | _ => progress simpl in *
      | _ => progress subst
      | [ H : ?a = ?b |- _ ] => progress subst a
      | [ H : ?a = ?b |- _ ] => progress subst b
      | _ => rewrite (LeftId string_stringlike _)
      | _ => rewrite (RightId string_stringlike _)
      | _ => reflexivity
      | _ => split
      | _ => right; reflexivity
      | _ => rewrite map_length
      | _ => rewrite map_map
      | _ => rewrite length_append
      | _ => progress destruct_head_hnf prod
      | _ => progress destruct_head_hnf and
      | _ => progress destruct_head_hnf or
      | _ => progress destruct_head_hnf sig
      | _ => progress auto with arith
      | _ => apply f_equal
      | _ => solve [ apply proj2_sig ]
      | _ => solve [ left; auto with arith ]
      | [ str : string |- _ ] => solve [ destruct str; simpl; auto with arith ]
      | [ str : string |- _ ] => solve [ left; destruct str; simpl; auto with arith ]
    end.
  Local Ltac t'' :=
    match goal with
      | _ => progress t'
      | [ str : string |- _ ] => solve [ destruct str; repeat t' ]
    end.
  Local Ltac t :=
    solve [ repeat t'' ].

  Local Hint Resolve NPeano.Nat.lt_lt_add_l NPeano.Nat.lt_lt_add_r NPeano.Nat.lt_add_pos_r NPeano.Nat.lt_add_pos_l : arith.

  Fixpoint brute_force_splitter_helper
           (prod : production Ascii.ascii)
  : forall str : string_stringlike,
      list
        (list
           {str_part : string_stringlike |
            Length string_stringlike str_part < Length string_stringlike str \/
            str_part = str}).
  Proof.
    refine (match prod with
              | nil => fun str =>
                         (** We only get one thing in the list *)
                         (((exist _ str _)::nil)::nil)
              | _::prod' => fun str =>
                              (flatten1
                                 (map (fun s1s2p =>
                                         map
                                           (fun split_list => ((exist _ (fst (proj1_sig s1s2p)) _)
                                                                 ::(map (fun s => exist _ (proj1_sig s) _)
                                                                        split_list)))
                                           (@brute_force_splitter_helper prod' (snd (proj1_sig s1s2p))))
                                      (make_all_single_splits str)))
            end);
    subst_body;
    clear;
    abstract t.
  Defined.

  Definition brute_force_splitter
  : forall (str : string_stringlike) (prod : production Ascii.ascii),
      list
        (list
           { str_part : string_stringlike |
             Length string_stringlike str_part < Length string_stringlike str \/
             str_part = str })
    := fun str prods =>
         match prods with
           | nil => nil (** no patterns, no split (actually, we should never encounter this case *)
           | _::prods' => brute_force_splitter_helper prods' str
         end.

  Variable G : grammar Ascii.ascii.
  Variable all_productions : list (productions Ascii.ascii).

  Definition brute_force_make_parse_of : @String Ascii.ascii string_stringlike
                                         -> productions Ascii.ascii
                                         -> bool
    := parse_productions
         string_stringlike
         G
         all_productions
         (rdp_list_is_valid_productions Ascii.ascii_dec)
         (rdp_list_remove_productions Ascii.ascii_dec)
         (rdp_list_remove_productions_dec Ascii.ascii_dec) rdp_list_ntl_wf
         brute_force_splitter.
End example_parse_string_grammar.

Module example_parse_empty_grammar.
  Definition make_parse_of : forall (str : string)
                                    (prods : productions Ascii.ascii),
                               bool
    := @brute_force_make_parse_of (trivial_grammar _) (map (Lookup (trivial_grammar _)) (""::nil)%string).



  Definition parse : string -> bool
    := fun str => make_parse_of str (trivial_grammar _).

  Time Compute parse "".
  Check eq_refl : true = parse "".
  Time Compute parse "a".
  Check eq_refl : false = parse "a".
  Time Compute parse "aa".
  Check eq_refl : false = parse "aa".
End example_parse_empty_grammar.

Section examples.
  Section ab_star.

    Fixpoint production_of_string (s : string) : production Ascii.ascii
      := match s with
           | EmptyString => nil
           | String.String ch s' => (Terminal ch)::production_of_string s'
         end.

    Coercion production_of_string : string >-> production.

    Fixpoint list_to_productions {T} (default : T) (ls : list (string * T)) : string -> T
      := match ls with
           | nil => fun _ => default
           | (str, t)::ls' => fun s => if string_dec str s
                                       then t
                                       else list_to_productions default ls' s
         end.

    Delimit Scope item_scope with item.
    Bind Scope item_scope with item.
    Delimit Scope production_scope with production.
    Delimit Scope production_assignment_scope with prod_assignment.
    Bind Scope production_scope with production.
    Delimit Scope productions_scope with productions.
    Delimit Scope productions_assignment_scope with prods_assignment.
    Bind Scope productions_scope with productions.
    Notation "n0 ::== r0" := ((n0 : string)%string, (r0 : productions _)%productions) (at level 100) : production_assignment_scope.
    Notation "[[[ x ;; .. ;; y ]]]" :=
      (list_to_productions (nil::nil) (cons x%prod_assignment .. (cons y%prod_assignment nil) .. )) : productions_assignment_scope.

    Local Open Scope string_scope.
    Notation "<< x | .. | y >>" :=
      (@cons (production _) (x)%production .. (@cons (production _) (y)%production nil) .. ) : productions_scope.

    Notation "$< x $ .. $ y >$" := (cons (NonTerminal _ x) .. (cons (NonTerminal _ y) nil) .. ) : production_scope.

    Definition ab_star_grammar : grammar Ascii.ascii :=
      {| Top_name := "ab_star";
         Lookup := [[[ ("" ::== (<< "" >>)) ;;
                       ("ab" ::== << "ab" >>) ;;
                       ("ab_star" ::== << $< "" >$
                                        | $< "ab" $ "ab_star" >$ >> ) ]]]%prods_assignment |}.

    Definition make_parse_of : forall (str : string)
                                      (prods : productions Ascii.ascii),
                                 bool
      := @brute_force_make_parse_of ab_star_grammar (map (Lookup ab_star_grammar) (""::"ab"::"ab_star"::nil)%string).



    Definition parse : string -> bool
      := fun str => make_parse_of str ab_star_grammar.

    Time Compute parse "".
    Check eq_refl : parse "" = true.
    Time Compute parse "a".
    Check eq_refl : parse "a" = false.
    Time Compute parse "ab".
    Check eq_refl : parse "ab" = true.
    Time Compute parse "aa".
    Check eq_refl : parse "aa" = false.
    Time Compute parse "ba".
    Check eq_refl : parse "ba" = false.
    Time Compute parse "aba".
    Check eq_refl : parse "aba" = false.
    Time Compute parse "abab".
    Time Compute parse "ababab".
    Check eq_refl : parse "abab" = true.
  (* For debugging: *)(*
  Goal True.
    pose proof (eq_refl (parse "abab")) as s.
    unfold parse in s.
    unfold make_parse_of in s.
    unfold brute_force_make_parse_of in s.
    cbv beta zeta delta [parse_productions] in s.
    cbv beta zeta delta [parse_productions_or_abort] in s.
    rewrite Init.Wf.Fix_eq in s.
    Ltac do_compute_in c H :=
      let c' := (eval compute in c) in
      change c with c' in H.
    do_compute_in (lt_dec (Length string_stringlike "abab"%string) (Length string_stringlike "abab"%string)) s.
    change (if in_right then ?x else ?y) with y in s.
    cbv beta zeta delta [rdp_list_is_valid_productions] in s.
                       *)
  End ab_star.
End examples.

    Lemma
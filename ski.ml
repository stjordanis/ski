(* set to true to output debug information *)
let debug = ref false

(* lambda calculus AST *)
type name = string
type lambda =
  | Var of name
  | App of lambda * lambda
  | Abs of name * lambda

(* the SKI AST *)
type ski =
  | I
  | K
  | S
  | T of ski * ski

(* pretty print *)
let rec string_of_ski = function
  | I -> "I"
  | K -> "K"
  | S -> "S"
  | T (x, y) -> "T(" ^ (string_of_ski x) ^ "," ^ (string_of_ski y) ^ ")"

(* Rules for SKI calculus *)
(* I x     = x            *)
(* K x y   = x            *)
(* S x y z = x z (y z)    *)

let rec interp c =
  if !debug then print_endline ("pre: " ^ (string_of_ski c));
  match c with
  (* leaf node, remain unchanged *)
  | I | K | S              -> c
  (* an I term, reduce argument *)
  | T (I, x)               -> interp x
  (* a K term, reduce first argument *)
  | T (T (K, x), y)        -> interp x
  (* an S term, perform substitution *)
  | T (T (T (S, x), y), z) ->
    interp (T (T (x, z), T (y, z)))
  (* any other term *)
  (* the goal here is to check if terms are reducible *)
  (* to prevent infinite recursion   *)
  | T (c1, c2)             ->
    let c1' = interp c1 in
    let c2' = interp c2 in
    if c1 = c1' && c2 = c2'
    then T (c1, c2)
    else interp (T (c1', c2'))

type step =
  (* able to perform next step with term and current stack *)
  | Step of (ski * ski list)
  (* no reduction possible anymore *)
  | End of ski

let step term stack =
  match (term, stack) with
  (* I term, work on the top term in the stack *)
  | I, x::s -> Step(x , s)
  (* K term, work on the top term, discard the second *)
  | K, x::y::s -> Step(x, s)
  (* works on the substituted term *)
  | S, x::y::z::s ->
    Step(T (T (x, z), T(y, z)), s)
  (* push the second pargument onto the stack *)
  | T (c1, c2), s -> Step(c1, c2 :: s)
  (* empty stack, return as the result of reduction *)
  | e, [] -> End e
  (* no idea how to handle this *)
  | _ -> failwith "Unrecognized term"


let pr term stack =
  let _ = print_endline ("term: " ^ (string_of_ski term)) in
  let _ = print_endline ("stack: [" ^ (String.concat ", " (List.map string_of_ski stack)) ^ "]") in
  ()

let rec run term =
  let rec go term stack =
    if !debug then pr term stack;
    match step term stack with
    | End e -> print_endline ("end: " ^ (string_of_ski e)); e
    | Step(e, s') -> go e s';
  in
  go term []

(* examples from the blog post *)
let eg1 = T (I, I)
let eg2 = T (T (K, K), I)
let eg3 = T (T (T (S, K), S), K)

(* running examples on interpreter *)
(* helper to print interpreter result *)
let pr_interp t c = t ^ ": " ^ (string_of_ski (interp c))
let _ = print_endline (pr_interp "eg1" eg1) (* should be I *)
let _ = print_endline (pr_interp "eg2" eg2) (* should be K *)
let _ = print_endline (pr_interp "eg3" eg3) (* should be K *)

(* running examples on stack machine *)
let _ = run eg1 (* should be I *)
let _ = run eg2 (* should be K *)
let _ = run eg2 (* should be K *)

(* WIP *)
(* boolean logic in SKI combinator calculus *)
(* let z = s k s k *)
let t1 = T (T (K, T(T(K, I), I)), I)
(* K (K I I) I
 * K I I
 * *)
let t = K
let f = T (S, K)
    (* T (T (T (S, K), S), K) *)
let ifte b t e = T (T (b, t), e)
(* let nt = T(f, t) *)
let nt = function
  | K -> T (T (K, f), t)
  | T (S, K) -> T (T (T (S, K), T (S, K)), K)
  | _ -> failwith "not a boolean"
(* (SK) (SK) (K) (T) (F) *)
let t2 = ifte t (I) (K)
let t3 = ifte f (I) (K)
let t4 = ifte (nt t) (I) (K)
(*                       F           T *)
let t5 = ifte (T (T (f, (T (S, K))), K)) (I) (K)
(* let t5 = T (f, nt) *)
(* let t5 = T ((T(f, f), t)) *)
(* let _ = print_endline (pr_interp "t1" t1) (1* should be I *1) *)
(* let _ = print_endline (pr_interp "t2" t2) (1* should be I *1) *)
(* let _ = print_endline (pr_interp "t3" t3) (1* should be K *1) *)
(* let _ = print_endline (pr_interp "t4" t4) (1* should be k *1) *)
(* let _ = print_endline (pr_interp "t5" t5) (1* should be I *1) *)


(* Completeness of SKI combinators *)
(* Any lambda term can be translated to just SKI combinators *)

(* Intermediate AST for converting lambda calculus into SKI combinators.
 * This is needed because when converting, intermediate terms can be
 * a mixture of both lambda terms and SKI terms, for example
 * a lambda expression with a SKI body, \x . K
 * *)
type ls =
  | Var of name
  | App of ls * ls
  | Abs of name * ls
  | Sl
  | Kl
  | Il
  | Tl of ls * ls

(* String representation of ls *)
let rec string_of_lc (l : ls) : string = match l with
    | Var x -> x
    | App (e1, e2) -> "(" ^ (string_of_lc e1) ^ (string_of_lc e2) ^ ")"
    | Abs (x, e) -> "\\" ^ x ^ (string_of_lc e)
    | Sl  -> "S"
    | Kl  -> "K"
    | Il  -> "I"
    | Tl (e1, e2) ->  "(T " ^ (string_of_lc e1) ^ (string_of_lc e2) ^ ")"

(* Is n free in the expression e? *)
let free n (e : ls) =
  (* Get free variables of an expression *)
  let rec fv (e : ls) = match e with
    | Var n -> [n]
    | App (e1, e2) -> fv e1 @ fv e2
    | Abs (n, e) -> List.filter (fun x -> x != n) (fv e)
    | Tl (e1, e2) -> fv e1 @ fv e2
    | _ -> []
  in
  List.mem n (fv e)

(* This is the core algorithm to convert lambda terms into SKI combinators *)
(* Translates a lambda term into an intermediate structure that can hold both lambda and SKI *)
(* the clauses described here follows the rules of the T function described at *)
(* https://en.wikipedia.org/wiki/Combinatory_logic#Completeness_of_the_S-K_basis *)
let rec translate (e : ls) : ls = match e with
  (* clause 1. *)
  | Var x ->
    Var x
  (* clause 2. *)
  | App (e1, e2) ->
    App (translate e1, translate e2)
  (* clause 3. *)
  | Abs (x, e) when not (free x e) ->
    App (Kl, translate e)
  (* clause 4. *)
  | Abs (n, Var n') ->
    (* lambda x : x becomes identity *)
    if n = n'
    then Il
    else failwith "error"
  (* clause 5. *)
  | Abs (x, Abs (y, e)) ->
    if free x e
    then translate (Abs (x, translate (Abs (y, e))))
    else failwith "error"
  (* clause 6. *)
  | Abs (x, App (e1, e2)) ->
    if free x e1 || free x e2
    (* then App (Sl, App (translate (Abs (x, e1)), translate (Abs (x, e2)))) *)
    then App (App (Sl, (translate (Abs (x, e1)))), translate (Abs (x, e2)))
    else failwith "error"
  | Kl -> Kl
  | Sl -> Sl
  | Il -> Il
  | _ ->
    failwith ("no matches for " ^ (string_of_lc e))

(* Converts a lambda term into an SKI term *)
let convert (e : lambda) : ski =
  (* Convert lambda term into intermediate ls term *)
  let rec ls_of_lambda (e : lambda) =
    match e with
    | Var x -> Var x
    | App (e1, e2) -> App (ls_of_lambda e1, ls_of_lambda e2)
    | Abs (x, e) -> Abs (x, ls_of_lambda e)
  in
  let rec ski_of_ls (e : ls) : ski =
    match e with
    | Var _ -> failwith "shouldn't have Var anymore"
    | Abs _ -> failwith "shouldn't have Abs anymore"
    | App (e1, e2) -> T (ski_of_ls e1, ski_of_ls e2)
    | Sl  -> S
    | Kl  -> K
    | Il  -> I
    | Tl (e1, e2) -> T (ski_of_ls e1, ski_of_ls e2)
  in
  (* convert lambda term into ls term *)
  let ls_term = ls_of_lambda e in
  (* translate ls term of lambda into ls term of combinators *)
  let ls_comb = translate ls_term in
  (* convert ls term into ski *)
  ski_of_ls ls_comb

(* Example lambda terms *)
let l1 : lambda = Abs ("x", Var "x")
let l2 : lambda = Abs ("x", Abs ("y", App (Var "y", Var "x")))

let _ = print_endline (string_of_ski (convert l2))

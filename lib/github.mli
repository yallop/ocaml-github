(*
 * Copyright (c) 2012 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

(* All API requests are bound through this monad. The [run] function
 * will unpack an API response into an Lwt thread that will hold the
 * ultimate response. *)
module Monad : sig
  type 'a t
  val bind : 'a t -> ('a -> 'b t) -> 'b t
  val return : 'a -> 'a t
  val run : 'a t -> 'a Lwt.t
  val (>>=) : 'a t -> ('a -> 'b t) -> 'b t
end

(* Authorization scopes *)
module Scopes : sig
  type scope = User | Public_repo | Repo | Gist
  val scope_to_string : scope -> string
  val scope_of_string : string -> scope option
  val scopes_to_string : scope list -> string
  val scopes_of_string : string -> scope list
end

(* Authorization request, normally not used (a link in the HTML is
 * sufficient to redirect user to Github *)
val authorize : ?scopes:Scopes.scope list -> client_id:string -> unit -> unit Monad.t

(* Access token to the API, usually obtained via a user oAuth *)
type token
val token_of_code : client_id:string -> client_secret:string -> code:string -> unit -> token Monad.t
val token_of_string : string -> token
val token_to_string : token -> string

(* Generic get function, not normally used directly, but useful in case you
 * wish to call an API call that isn't wrapped in the rest of the library (i.e. most
 * of them!)
 *)
val get : ?headers:Cohttpd.Client.headers -> token:string -> Uri.t ->
  (headers:Cohttpd.Client.headers -> body:string -> 'a) -> 'a Monad.t

(* Various useful URI generation functions, normally for displaying on a web-page.
 * The [authorize] function is the entry URL for your users, and the [token] URI
 * is the URI used to convert the result into a concrete access token *)
module URI : sig
  val authorize : ?scopes:Scopes.scope list -> client_id:string -> unit -> Uri.t
  val token : client_id:string -> client_secret:string -> code:string -> unit -> Uri.t
end

(* Github users *)
module User : sig
  type t = {
    login : string;
    id : int;
    avatar_url : Uri.t option;
    gravatar_id : string option;
    url : Uri.t;
  }
  val of_json : Yojson.Basic.json -> t
end

(* Github issues *)
module Issues : sig
  type filter = [ `Assigned | `Created | `Mentioned | `Subscribed ]
  type state = [ `Closed | `Open ]
  val to_state : Yojson.Basic.json -> [> `Closed | `Open ]
  type sort = [ `Comments | `Created | `Updated ]
  type direction = [ `Ascending | `Descending ]
  type milestone = [ `Any | `Int of int | `None ]
  type issue = {
    url : Uri.t;
    html_url : Uri.t;
    number : int;
    state : state;
    title : string;
    body : string;
    user : User.t;
    assignee : User.t option;
  }
  val of_json : Yojson.Basic.json -> issue
  val repo :
    ?milestone:milestone -> ?state:state -> ?mentioned:string list ->
    ?labels:'b -> ?sort:sort -> ?direction:direction -> token:token ->
    user:string -> repo:string -> unit -> issue list Monad.t

end
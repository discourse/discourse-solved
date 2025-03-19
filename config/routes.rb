# frozen_string_literal: true

DiscourseSolved::Engine.routes.draw do
  post "/accept" => "answer#accept"
  post "/unaccept" => "answer#unaccept"
end

Discourse::Application.routes.append { mount ::DiscourseSolved::Engine, at: "solution" }

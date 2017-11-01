Dashing::Engine.routes.draw do
  resources :events, only: :index do
    delete '/close_stream', action: :close_stream, on: :collection
  end

  resources :dashboards,  only: :index do
    get '/:name', action: :show,    on: :collection
  end

  resources :widgets,     only: [] do
    get '/:name', action: :show,    on: :collection
    put '/:name', action: :update,  on: :collection
  end

  root to: 'dashboards#index'
end
